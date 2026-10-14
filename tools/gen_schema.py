#!/usr/bin/env python3
"""온톨로지 기반 데이터레이크 DDL 중 '생성' 부분을 만든다.

출력
  db/schema/10_ksx_tables.sql  표준 존: KS X 9101 70 테이블 (참고 DDL + 레이크 기술 컬럼 + 주석)
  db/schema/11_ksx_fk.sql      표준 존: 관계목록 → FK (DEFERRABLE)
  db/schema/90_seed_ontology.sql  onto·catalog 시드 (클래스·속성·관계·데이터셋 등록)

손으로 쓴 파일(00·20·30·40·50·60·70)은 이 스크립트가 건드리지 않는다.
"""
import csv, json, os, re
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source_extracts")
ONT = os.path.join(ROOT, "ontology")
OUT = os.path.join(ROOT, "db", "schema")
RESERVED = {"return"}           # PostgreSQL 예약어
KSX = "https://ontology.impix.co.kr/ksx9101/"
ARCON = "https://ontology.impix.co.kr/arcon/"
LAKE = "https://ontology.impix.co.kr/lake/"
KSXV = "https://ontology.impix.co.kr/ksx9101/verb/"
VERSION_ID = "ksx9101-2025-v1.0-gen-0.2.0"
# 이벤트 시각으로 월 파티션하는 표준 존 대형 테이블 (리뷰 F22)
EVENT_PARTITIONS = {"trace_parameter": "event_date_time", "alarm": "event_date_time",
                    "operation_start": "operation_start_time", "operation_end": "operation_end_time"}
# FK 로 만들지 않는 기본 속성 (리뷰 F12): 원천 시스템의 등록자·수정자가 MES 사원 마스터에 없는 경우가 흔하다 → SHACL 로 검증
NO_FK_ATTRS = {"CreatorID", "ModifierID"}
# 인덱스를 만들지 않는 FK 컬럼 (선택도가 낮아 쓰기 비용만 큼). 이벤트 테이블은 (회사, 공장, 시각) 복합 인덱스로 대신한다.
NO_INDEX_COLS = {"enterprise_id, site_id", "enterprise_id, plant_id", "enterprise_id, creator_id", "enterprise_id, modifier_id"}
# 레이크 기술 컬럼 → lake_meta.ttl 속성 (리뷰 F18: 카탈로그에도 등록해 Text-to-SQL 이 계보를 설명할 수 있게)
TECH_FIELDS = [("lake_batch_id", "적재 배치", "UUID", "ingestBatch"),
               ("lake_source_system", "원천 시스템 코드", "VARCHAR(50)", "recordSourceSystem"),
               ("lake_loaded_at", "표준 존 적재 시각", "TIMESTAMPTZ", "loadedAt"),
               ("lake_record_hash", "업무 컬럼 해시", "CHAR(64)", "recordHash"),
               ("lake_shacl_status", "SHACL 검증 상태", "VARCHAR(10)", "shaclStatus")]


def tsv(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return [{k: (v or "") for k, v in r.items()} for r in csv.DictReader(f, delimiter="\t")]


def snake(name):
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s)
    return s.lower()


def q(ident):
    return f'"{ident}"' if ident in RESERVED else ident


def lit(s):
    return "'" + (s or "").replace("'", "''") + "'"


def main():
    tables = [t for t in tsv("tabdef_02_테이블목록.tsv") if t["테이블명(영문)"]]
    cols = tsv("tabdef_01_테이블정의서.tsv")
    rels = tsv("tabdef_03_관계목록.tsv")
    phys = {t["테이블명(영문)"]: t["물리 테이블명"] for t in tables}
    colphys = {(c["테이블명(영문)"], c["컬럼명(영문)"]): c["물리 컬럼명"] for c in cols}

    # ---------------------------------------------------------------- 10 tables
    ref = open(os.path.join(SRC, "ksx9101_ddl_reference.sql"), encoding="utf-8").read()
    body = re.sub(r"CREATE TABLE (\w+) \(", lambda m: f"CREATE TABLE ksx.{q(m.group(1))} (", ref)
    body = body.replace("CREATE TABLE ksx.return", 'CREATE TABLE ksx."return"')
    out = ["-- =============================================================================",
           "-- 표준 존(StandardZone) · KS X 9101-1:2025 v1.0 — 70 테이블",
           "-- 생성: tools/gen_schema.py (원천: 테이블정의서 DDL 시트). 수기 편집 금지.",
           "-- 각 테이블 끝에 레이크 기술 컬럼 5개를 덧붙인다(계보·적재·검증 상태).",
           "-- =============================================================================",
           "SET client_min_messages = warning;", ""]
    # 레이크 기술 컬럼을 각 테이블의 PK 제약 직전에 삽입
    tech = ("    lake_batch_id UUID, -- 적재 배치(raw.ingest_batch)\n"
            "    lake_source_system VARCHAR(50), -- 원천 시스템 코드(catalog.source_system)\n"
            "    lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- 표준 존 적재 시각\n"
            "    lake_record_hash CHAR(64), -- 업무 컬럼 해시(변경 감지·CDC)\n"
            "    lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION')), -- SHACL 검증 상태\n")
    body = re.sub(r"(\n)(    CONSTRAINT (?:uk|pk)_\w+ (?:PRIMARY KEY|UNIQUE))", lambda m: m.group(1) + tech + m.group(2), body, count=0)
    # 같은 테이블에 UNIQUE 와 PK 가 둘 다 있으면 tech 가 두 번 들어가므로 두 번째 것을 제거
    body = re.sub(r"(" + re.escape(tech) + r"    CONSTRAINT uk_[^\n]+\n)" + re.escape(tech), r"\1", body)
    # 대형 이벤트 테이블은 이벤트 시각 월 파티션 (리뷰 F22). PK 에 시각이 있고, 이 테이블들을 참조하는 FK 는 없다.
    # 보존은 DELETE 대신 오래된 파티션 DETACH/DROP. 새 파티션은 gov.ensure_partitions 가 매일 만든다.
    for t, col in EVENT_PARTITIONS.items():
        body, n = re.subn(r"(CREATE TABLE ksx\." + t + r" \([^;]*?\n)\);",
                          lambda m: m.group(1) + f") PARTITION BY RANGE ({col});\n"
                          f"CREATE TABLE ksx.{t}_default PARTITION OF ksx.{t} DEFAULT;\n"
                          f"SELECT gov.ensure_partitions('ksx.{t}', 'month', 3);\n"
                          f"CREATE INDEX ix_{t}_plant_time ON ksx.{t} (enterprise_id, plant_id, {col});", body, count=1)
        assert n == 1, t
    out.append(body)
    # 테이블·컬럼 주석
    out.append("\n-- 국문 주석 (카탈로그·Text-to-SQL 이 읽는다)")
    for t in tables:
        out.append(f"COMMENT ON TABLE ksx.{q(t['물리 테이블명'])} IS {lit(t['테이블명(국문)'] + ' — ' + t['테이블 설명(표준 정의)'])};")
    seen = set()
    for c in cols:
        key = (c["물리 테이블명"], c["물리 컬럼명"])
        if key in seen or not c["물리 컬럼명"]:
            continue
        seen.add(key)
        out.append(f"COMMENT ON COLUMN ksx.{q(c['물리 테이블명'])}.{c['물리 컬럼명']} IS {lit(c['속성명(국문)'])};")
    open(os.path.join(OUT, "10_ksx_tables.sql"), "w", encoding="utf-8").write("\n".join(out) + "\n")

    # ---------------------------------------------------------------- 11 FK
    fk = ["-- =============================================================================",
          "-- 표준 존 FK — 관계목록 575행 중 물리 FK 로 옮길 수 있는 것",
          "-- 생성: tools/gen_schema.py",
          "-- 모두 DEFERRABLE INITIALLY DEFERRED: 레이크 적재는 원천별로 순서가 뒤섞여 들어오므로",
          "-- 한 적재 트랜잭션 안에서는 순서를 따지지 않고, 커밋 시점에만 정합성을 본다.",
          "-- 비용 (리뷰 F11, 30만 행·FK 7개 실측): 지연 검사는 커밋에 몰려 적재 시간의 ~64%. 지연 큐는 커밋까지 메모리에 남는다.",
          "--   · 적재 트랜잭션은 50만 행 이하로 자른다.",
          "--   · 부모가 먼저 들어오는 원천(기준정보 → 트랜잭션)은 SET CONSTRAINTS ALL IMMEDIATE.",
          "--   · 초기 적재·백필은 gov.fk_bulk_begin('ksx.x') → COPY → gov.fk_bulk_end('ksx.x') (FK 를 NOT VALID 로 다시 걸고 나눠 VALIDATE).",
          "-- 기존 데이터에 걸 때는 NOT VALID 로 먼저 걸고 VALIDATE CONSTRAINT 로 나눠 검증한다.",
          "-- 제외: 다형 참조 4 · 표준 외 대상 3 · 하위 목록 참조 1 (→ SHACL/애플리케이션 검증)",
          "-- =============================================================================", ""]
    n_by = defaultdict(int)
    skipped = []
    no_fk = []
    made = 0
    for r in rels:
        kind = r["관계 구분"]
        if kind in ("다형 참조", "표준 외 대상", "하위 목록 참조") or not r["자식 테이블"]:
            skipped.append(r)
            continue
        child, parent = r["자식 테이블"], r["부모 테이블"]
        ccols = [x.strip() for x in r["FK 컬럼"].split(",")]
        pcols = [x.strip() for x in r["부모 키 컬럼"].split(",")]
        if NO_FK_ATTRS & set(ccols):
            no_fk.append(r)
            continue
        try:
            cphys = [colphys[(child, c)] for c in ccols]
            pphys = [colphys[(parent, c)] for c in pcols]
        except KeyError as e:
            skipped.append(r)
            continue
        if child == parent and cphys == pphys:
            continue
        n_by[child] += 1
        name = f"fk_{phys[child]}_{n_by[child]:02d}"[:63]
        fk.append(f"ALTER TABLE ksx.{q(phys[child])} ADD CONSTRAINT {name} FOREIGN KEY ({', '.join(cphys)})\n"
                  f"    REFERENCES ksx.{q(phys[parent])} ({', '.join(pphys)}) DEFERRABLE INITIALLY DEFERRED; -- {kind}: {r['비고'] or ''}".rstrip())
        made += 1
    fk.append("")
    fk.append("-- FK 로 옮기지 않은 관계 (SHACL·애플리케이션 검증 대상)")
    for r in skipped:
        if r["자식 테이블"]:
            fk.append(f"--   {r['자식 테이블']}.{r['FK 컬럼']} → {r['부모 테이블']} [{r['관계 구분']}] {r['비고']}")
    fk.append(f"-- 등록자·수정자(CreatorID·ModifierID → Personnel) {len(no_fk)}건도 FK 로 만들지 않는다 (리뷰 F12).")
    fk.append("--   ERP·HR·EAP 의 등록자 ID 는 MES 사원 마스터에 없는 경우가 흔해 배치 커밋이 실패한다. SHACL 경고로만 검증한다.")
    # FK 컬럼 인덱스 (조인·계보 추적 성능)
    fk.append("\n-- FK 컬럼 인덱스. 생략: EnterpriseID 단독(PK 선두와 겹침), 사업장·공장(선택도 낮음, 리뷰 F12)")
    idx_seen = set()
    for line in list(fk):
        m = re.match(r"ALTER TABLE ksx\.(\S+) ADD CONSTRAINT (\S+) FOREIGN KEY \(([^)]*)\)", line)
        if not m:
            continue
        t, cn, cs = m.group(1), m.group(2), m.group(3)
        if cs.strip() == "enterprise_id" or cs.strip() in NO_INDEX_COLS or (t, cs) in idx_seen:
            continue
        idx_seen.add((t, cs))
        fk.append(f"CREATE INDEX IF NOT EXISTS ix_{cn[3:]} ON ksx.{t} ({cs});")
    open(os.path.join(OUT, "11_ksx_fk.sql"), "w", encoding="utf-8").write("\n".join(fk) + "\n")

    # ---------------------------------------------------------------- 90 seed
    model = json.load(open(os.path.join(ONT, "ontology_model.json"), encoding="utf-8"))
    import rdflib
    RDF, RDFS, OWL = rdflib.RDF, rdflib.RDFS, rdflib.OWL
    KS = rdflib.Namespace(KSX)
    g = rdflib.Graph().parse(os.path.join(ONT, "ksx9101_core.ttl"))
    # 레지스트리는 코어 + 기업 확장 + 레이크 메타를 모두 담는다 (리뷰 F16). 액션·리스크·정책이 arcon 클래스를 가리키기 때문.
    gall = rdflib.Graph()
    for f in ("ksx9101_core.ttl", "arcon_ext.ttl", "lake_meta.ttl"):
        gall.parse(os.path.join(ONT, f))
    OURS = (KSX, ARCON, LAKE)       # ksxv(동사)는 onto.action.verb 로 관리하므로 제외

    def ours(x):
        return isinstance(x, rdflib.URIRef) and str(x).startswith(OURS) and not str(x).startswith(KSXV)

    def label_ko(x):
        return next((str(o) for o in gall.objects(x, RDFS.label) if getattr(o, "language", None) == "ko"), "")

    def local(x):
        s = str(x)
        return s.rsplit("/", 1)[1]

    sd = ["-- =============================================================================",
          "-- 온톨로지 레지스트리·카탈로그 시드 — 생성: tools/gen_schema.py",
          "-- 레지스트리는 항상 현재 릴리스만 담는다(upsert). 과거 버전은 onto.ontology_version.artifact_uri 의 TTL 번들로 보관 (리뷰 F17).",
          "-- 트랜잭션은 apply 스크립트가 파일 단위로 묶는다(psql -1).",
          "-- =============================================================================", ""]
    sd.append("INSERT INTO onto.ontology_version (version_id, ontology_iri, version_info, source, status) VALUES\n"
              f"  ('{VERSION_ID}', 'https://ontology.impix.co.kr/ksx9101', '9101-1:2025-v1.0/gen-0.2.0',"
              " 'KSX9101-1_2025_온톨로지용v1.0_테이블정의서.xlsx + arcon_ext.ttl + lake_meta.ttl', 'DRAFT')\n"
              "ON CONFLICT (version_id) DO NOTHING;")
    # 클래스: 표준 명사 70(모델 JSON) + TTL 의 나머지 owl:Class (상위 분류·arcon 확장·lake 메타)
    rows, have = [], set()
    def parent_of(iri):
        ps = sorted(str(o) for o in gall.objects(rdflib.URIRef(iri), RDFS.subClassOf) if ours(o))
        return ps[0] if ps else None
    for c in model["classes"]:
        iri = c['iri'].replace('ksx:', KSX).replace('arcon:', ARCON)
        have.add(iri)
        rows.append((iri, c['name'], c['label'], c['group'], c['clause'] if c['clause'] != '—' else '', c['table'], c['pk'],
                     c['event'], not iri.startswith(ARCON), c['definition']))
    for x in sorted(set(gall.subjects(RDF.type, OWL.Class)), key=str):
        if not ours(x) or str(x) in have:
            continue
        have.add(str(x))
        grp = "표준 분류" if str(x).startswith(KSX) else ("기업 확장" if str(x).startswith(ARCON) else "레이크 메타")
        comment = next((str(o) for o in gall.objects(x, RDFS.comment)), "")
        rows.append((str(x), local(x), label_ko(x) or local(x), grp, '', '', '', False, str(x).startswith(KSX), comment))
    vals = []
    for (iri, name, label, grp, clause, table, pk, ev, std, dfn) in rows:
        par = parent_of(iri)
        par = par if par in have and par != iri else None
        vals.append(f"  ({lit(iri)}, {lit(name)}, {lit(label)}, {lit(grp)}, {lit(clause) if clause else 'NULL'}, "
                    f"{lit(table) if table else 'NULL'}, {lit(pk) if pk else 'NULL'}, {'TRUE' if ev else 'FALSE'}, "
                    f"{'TRUE' if std else 'FALSE'}, {lit(dfn)}, {lit(par) if par else 'NULL'}, '{VERSION_ID}')")
    sd.append("INSERT INTO onto.class (class_iri, local_name, label_ko, business_group, standard_clause, physical_table, primary_key, "
              "is_event, is_standard, definition_ko, parent_class_iri, version_id) VALUES\n" + ",\n".join(vals) +
              "\nON CONFLICT (class_iri) DO UPDATE SET label_ko = EXCLUDED.label_ko, business_group = EXCLUDED.business_group, "
              "standard_clause = EXCLUDED.standard_clause, physical_table = EXCLUDED.physical_table, primary_key = EXCLUDED.primary_key, "
              "is_event = EXCLUDED.is_event, is_standard = EXCLUDED.is_standard, definition_ko = EXCLUDED.definition_ko, "
              "parent_class_iri = EXCLUDED.parent_class_iri, version_id = EXCLUDED.version_id;\n")
    # 속성: 세 TTL 의 Object/Datatype 속성 + 헤더-라인 링크 전용 하위 속성(arcon:hasHeader_*)
    prow, pseen = [], set()
    transitive = set(gall.subjects(RDF.type, OWL.TransitiveProperty))
    for s, kind in ((OWL.ObjectProperty, "OBJECT"), (OWL.DatatypeProperty, "DATATYPE")):
        for p in sorted(set(gall.subjects(RDF.type, s)), key=str):
            if not ours(p) or str(p) in pseen:
                continue
            pseen.add(str(p))
            rng = next((str(o) for o in gall.objects(p, RDFS.range)), "")
            k = "CODE" if rng.endswith("core#Concept") else kind
            scheme = next((str(o) for o in gall.objects(p, KS.codeScheme)), "")
            srcattr = next((str(o) for o in gall.objects(p, KS.sourceAttribute)), "")
            sup = next((str(o) for o in gall.objects(p, RDFS.subPropertyOf) if ours(o)), "")
            prow.append([str(p), local(p), k, label_ko(p), rng, scheme, srcattr, p in transitive, sup])
    for l in model["links"]:
        if l["p"].startswith("arcon:") and ARCON + l["p"][6:] not in pseen:
            iri = ARCON + l["p"][6:]
            pseen.add(iri)
            prow.append([iri, l["p"][6:], "OBJECT", f"헤더 참조({l['o']})", ARCON + l["o"], "", "", False, ARCON + "hasHeader"])
    known = {r[0] for r in prow}
    for r in prow:                 # 레지스트리 밖 상위 속성(prov:* 등)은 비운다
        if r[8] and r[8] not in known:
            r[8] = ""
    sd.append("INSERT INTO onto.property (property_iri, local_name, kind, label_ko, range_iri, code_scheme, source_attribute, is_transitive, super_property_iri, version_id) VALUES\n"
              + ",\n".join(f"  ({lit(a)}, {lit(b)}, {lit(c)}, {lit(d)}, {lit(e)}, {lit(f)}, {lit(h)}, {'TRUE' if t else 'FALSE'}, "
                           f"{lit(sp) if sp else 'NULL'}, '{VERSION_ID}')" for a, b, c, d, e, f, h, t, sp in prow)
              + "\nON CONFLICT (property_iri) DO UPDATE SET kind = EXCLUDED.kind, label_ko = EXCLUDED.label_ko, range_iri = EXCLUDED.range_iri, "
              "code_scheme = EXCLUDED.code_scheme, source_attribute = EXCLUDED.source_attribute, is_transitive = EXCLUDED.is_transitive, "
              "super_property_iri = EXCLUDED.super_property_iri, version_id = EXCLUDED.version_id;\n")
    lrow = []
    for l in model["links"]:
        p = l["p"] if l["p"].startswith("arcon:") else "ksx:" + l["p"]
        piri = p.replace("ksx:", KSX).replace("arcon:", ARCON)
        sub = (ARCON if l["s"] in ("BOMHeader", "RoutingHeader", "ProductReleaseRequestHeader") else KSX) + l["s"]
        obj = (ARCON if l["o"] in ("BOMHeader", "RoutingHeader", "ProductReleaseRequestHeader", "Location", "CustomerInstalledProduct") else KSX) + l["o"]
        lrow.append(f"  ({lit(sub)}, {lit(piri)}, {lit(obj)}, {lit(', '.join(l['fk']))}, {lit(l['kind'])})")
    sd.append("DELETE FROM onto.link;   -- 링크는 매 릴리스 전체 교체")
    sd.append("INSERT INTO onto.link (subject_class_iri, property_iri, object_class_iri, fk_columns, relation_kind) VALUES\n"
              + ",\n".join(lrow) + ";\n")
    # 표준 존 데이터셋 = 테이블 70 (enterprise_id NULL = 모든 회사 공용 정의)
    drow = []
    for c in model["classes"]:
        drow.append(f"  ({lit('std.' + c['table'])}, {lit(c['label'])}, 'STANDARD', {lit(c['iri'].replace('ksx:', KSX).replace('arcon:', ARCON))}, "
                    f"{lit('postgresql://lake/ksx.' + c['table'])}, 'table', 'batch', '9101-1:2025-v1.0', 'INTERNAL')")
    sd.append("INSERT INTO catalog.dataset (dataset_id, title_ko, zone_id, represents_class_iri, location_uri, format, ingest_mode, schema_version, sensitivity) VALUES\n"
              + ",\n".join(drow) + "\nON CONFLICT (dataset_id) DO UPDATE SET title_ko = EXCLUDED.title_ko, represents_class_iri = EXCLUDED.represents_class_iri, "
              "schema_version = EXCLUDED.schema_version;\n")
    # 컬럼 → 속성 매핑
    frow = []
    basic = {"EnterpriseID": "refEnterprise", "SiteID": "refSite", "PlantID": "refPlant",
             "CreatorID": "createdBy", "ModifierID": "modifiedBy"}
    local2iri = {str(p).rsplit("/", 1)[1]: str(p) for p in g.subjects(rdflib.RDF.type, None) if str(p).startswith(KSX)}
    linkprop = {}
    for l in model["links"]:
        lead = next((x for x in l["fk"] if x != "EnterpriseID"), l["fk"][0])
        if not l["p"].startswith("arcon:"):
            linkprop[(l["s"], lead)] = KSX + l["p"]
    seen = set()
    for cdef in cols:
        t, a = cdef["테이블명(영문)"], cdef["컬럼명(영문)"]
        if not t or (t, a) in seen:
            continue
        seen.add((t, a))
        tbl = phys[t]
        if a in basic and cdef["데이터 타입(표준)"] == "IDREF":
            piri = KSX + basic[a]
        elif (t, a) in linkprop:
            piri = linkprop[(t, a)]
        else:
            ln = re.sub(r"ID$", "Id", a[:1].lower() + a[1:])
            m = re.match(r"^([A-Z]+)(?=[A-Z][a-z]|$)", a)
            if m and len(m.group(1)) > 1:
                ln = re.sub(r"ID$", "Id", m.group(1).lower() + a[len(m.group(1)):])
            piri = local2iri.get(ln, "")
        frow.append(f"  ({lit('std.' + tbl)}, {lit(cdef['물리 컬럼명'])}, {lit(cdef['속성명(국문)'])}, {lit(cdef['물리 타입(권장)'])}, "
                    f"{'TRUE' if cdef['PK'] == 'Y' else 'FALSE'}, {'TRUE' if cdef['NOT NULL'] == 'Y' else 'FALSE'}, "
                    f"{lit(piri) if piri else 'NULL'}, 'rule', 1.0, 'APPROVED')")
    for c in model["classes"]:         # 기술 컬럼 5개도 카탈로그에 (리뷰 F18)
        for fname, flabel, ftype, fprop in TECH_FIELDS:
            frow.append(f"  ({lit('std.' + c['table'])}, {lit(fname)}, {lit(flabel)}, {lit(ftype)}, FALSE, "
                        f"{'FALSE' if fname in ('lake_batch_id', 'lake_source_system', 'lake_record_hash') else 'TRUE'}, "
                        f"{lit(LAKE + fprop)}, 'rule', 1.0, 'APPROVED')")
    # 시드는 규칙 매핑이므로 명시적으로 APPROVED. 테이블 기본값은 PROPOSED (리뷰 F31: 자동 매핑은 검토 큐로)
    sd.append("INSERT INTO catalog.dataset_field (dataset_id, field_name, label_ko, data_type, is_pk, is_required, maps_to_property_iri, mapping_method, mapping_confidence, mapping_status) VALUES\n"
              + ",\n".join(frow) + "\nON CONFLICT (dataset_id, field_name) DO UPDATE SET label_ko = EXCLUDED.label_ko, data_type = EXCLUDED.data_type, "
              "maps_to_property_iri = EXCLUDED.maps_to_property_iri;\n")
    open(os.path.join(OUT, "90_seed_ontology.sql"), "w", encoding="utf-8").write("\n".join(sd) + "\n")
    print(f"tables={len(tables)} fk={made} skipped={len([r for r in skipped if r['자식 테이블']])} props={len(prow)} links={len(lrow)} fields={len(frow)}")


if __name__ == "__main__":
    main()
