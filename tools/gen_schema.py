#!/usr/bin/env python3
"""표준 존(ksx) 물리 모델과 온톨로지 레지스트리 시드를 KS X 9101-1:2025 v1.0 최종본 테이블정의서에서 만든다.

입력  source_extracts/tabdef_*.tsv (테이블정의서 추출본), ontology/*.ttl·ontology_model.json (gen_ontology.py 결과)
출력
  db/reference/ksx_target.sql           표준 존 76 테이블의 목표 DDL (+ FK·주석). 참고용 — apply.sh 가 적용하지 않는다.
  db/schema/V0014__ksx9101_v1_final.sql tools/V0014.template.sql 의 @@…@@ 자리에 생성 조각(명세·FK·주석·시드)을 채운 마이그레이션

물리 규칙 (테이블정의서 '작성기준' 과 다른 점은 db/reference/ksx_target.sql 머리말에 적는다)
  · 이름은 snake_case (tools/ksxnames.snake). 표준 PascalCase 원문 이름은 온톨로지·카탈로그가 잇는다.
  · 기본키(PRIMARY KEY)는 식별 키(UK: 회사+식별 속성). 표준의 행 일련번호(○○SequenceNo)는 <표>_sequence_no 로 두고
    자동 증가 + 고유 인덱스만 건다(다른 표가 참조하지 않는 대리키라는 표준 정의 그대로). 적재·되돌리기·확장 속성이
    모두 업무 키로 행을 찾기 때문이다.
  · 이벤트 시각 월 파티션 표(착공·완공·알람·설비파라미터이력)는 파티션 열을 기본키에 덧붙인다(PostgreSQL 제약).
  · 등록자·수정자 → 사원 참조는 FK 로 만들지 않는다(리뷰 F12, SHACL 로 검증).
"""
import csv, json, os, re, sys
from collections import OrderedDict, defaultdict

from ksxnames import snake

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source_extracts")
ONT = os.path.join(ROOT, "ontology")
KSX = "https://ontology.impix.co.kr/ksx9101/"
ARCON = "https://ontology.impix.co.kr/arcon/"
LAKE = "https://ontology.impix.co.kr/lake/"
KSXV = "https://ontology.impix.co.kr/ksx9101/verb/"
VERSION_ID = "ksx9101-2025-v1.0-final-gen-0.3.0"
RESERVED = {"return"}
EVENT_PARTITIONS = {"trace_parameter": "event_date_time", "alarm": "event_date_time",
                    "operation_start": "operation_start_time", "operation_end": "operation_end_time"}
NO_FK_ATTRS = {"CreatorID", "ModifierID"}
NO_INDEX_COLS = {"enterprise_id, site_id", "enterprise_id, plant_id", "enterprise_id, creator_id", "enterprise_id, modifier_id"}
TECH_FIELDS = [("lake_batch_id", "적재 배치", "UUID", "ingestBatch"),
               ("lake_source_system", "원천 시스템 코드", "VARCHAR(50)", "recordSourceSystem"),
               ("lake_loaded_at", "표준 존 적재 시각", "TIMESTAMPTZ", "loadedAt"),
               ("lake_record_hash", "업무 컬럼 해시", "CHAR(64)", "recordHash"),
               ("lake_shacl_status", "SHACL 검증 상태", "VARCHAR(10)", "shaclStatus")]
TECH_DDL = ["lake_batch_id UUID", "lake_source_system VARCHAR(50)", "lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now()",
            "lake_record_hash CHAR(64)",
            "lake_shacl_status VARCHAR(10) NOT NULL DEFAULT 'PENDING' CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION'))"]


def tsv(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return [{k: (v or "") for k, v in r.items()} for r in csv.DictReader(f, delimiter="\t")]


def q(ident):
    return f'"{ident}"' if ident in RESERVED else ident


def lit(s):
    return "'" + (s or "").replace("'", "''") + "'"


def load():
    """표 → {phys, label, desc, uk[], cols[], seq} (물리명은 snake_case)."""
    tables = OrderedDict()
    for t in tsv("tabdef_02_테이블목록.tsv"):
        if not t["테이블명(영문)"]:
            continue
        name = t["테이블명(영문)"]
        tables[name] = dict(name=name, phys=snake(name), label=t["테이블명(국문)"], desc=t["테이블 설명(표준 정의)"],
                            uk=[snake(x.strip()) for x in t["UK(식별 키)"].split("+")], cols=[], seq=None)
    for c in tsv("tabdef_01_테이블정의서.tsv"):
        t = tables.get(c["테이블명(영문)"])
        if t is None:
            continue
        col = dict(attr=c["컬럼명(영문)"], phys=snake(c["컬럼명(영문)"]), label=c["속성명(국문)"], type=c["물리 타입(권장)"],
                   notnull=c["NOT NULL"] == "Y", std_type=c["데이터 타입(표준)"])
        if c["구분"] == "PK":
            t["seq"] = col
        elif all(x["phys"] != col["phys"] for x in t["cols"]):
            t["cols"].append(col)
    for t in tables.values():
        names = {c["phys"] for c in t["cols"]}
        assert t["seq"] and set(t["uk"]) <= names, (t["name"], t["uk"])
        t["pk"] = t["uk"] + ([EVENT_PARTITIONS[t["phys"]]] if t["phys"] in EVENT_PARTITIONS else [])
    return tables


def fks(tables):
    """관계목록의 물리 FK → (자식 표, 자식 열[], 부모 표, 부모 열[], 구분, 비고). 논리 관계는 따로 돌려준다."""
    colphys = {(t, c["attr"]): c["phys"] for t, td in tables.items() for c in td["cols"]}
    out, logical = [], []
    for r in tsv("tabdef_03_관계목록.tsv"):
        if not r["자식 테이블"]:
            continue
        ccols = [x.strip() for x in r["FK 컬럼"].split(",")]
        if r["FK 구분"] != "물리" or NO_FK_ATTRS & set(ccols):
            logical.append(r)
            continue
        child, parent = r["자식 테이블"], r["부모 테이블"]
        pcols = [x.strip() for x in r["부모 키 컬럼(UK)"].split(",")]
        cp = [colphys[(child, c)] for c in ccols]
        pp = [colphys[(parent, c)] for c in pcols]
        assert set(pp) == set(tables[parent]["uk"]) or pp == tables[parent]["uk"], (child, parent, pp)
        if child == parent and cp == pp:
            continue
        out.append((tables[child]["phys"], cp, tables[parent]["phys"], pp, r["관계 구분"], r["비고"]))
    return out, logical


def fk_sql(tables, rels):
    lines, n_by, idx = [], defaultdict(int), []
    for child, cp, parent, pp, kind, note in rels:
        n_by[child] += 1
        name = f"fk_{child}_{n_by[child]:02d}"[:63]
        lines.append(f"ALTER TABLE ksx.{q(child)} ADD CONSTRAINT {name} FOREIGN KEY ({', '.join(cp)})\n"
                     f"    REFERENCES ksx.{q(parent)} ({', '.join(pp)}) DEFERRABLE INITIALLY DEFERRED; -- {kind}{': ' + note if note else ''}")
        cs = ", ".join(cp)
        if cs != "enterprise_id" and cs not in NO_INDEX_COLS and (child, cs) not in {(a, b) for a, b, _ in idx}:
            idx.append((child, cs, name))
    lines.append("")
    lines += [f"CREATE INDEX IF NOT EXISTS ix_{name[3:]} ON ksx.{q(t)} ({cs});" for t, cs, name in idx]
    return "\n".join(lines)


def target_ddl(tables, rels, logical):
    out = ["-- =============================================================================",
           "-- 표준 존 목표 DDL · KS X 9101-1:2025 개정(안) v1.0 최종본 — 명사 68, 테이블 76",
           "-- 생성: tools/gen_schema.py. 참고용(새 설치 설계·검토). 실제 DB 는 db/schema 의 기준선 + V0014 로 이 모양이 된다.",
           "-- 테이블정의서와 다른 물리 선택 (이유는 tools/gen_schema.py 머리말):",
           "--   · snake_case 이름  · 기본키 = 식별 키(UK), 표준 행 일련번호는 <표>_sequence_no 자동 증가 + 고유 인덱스",
           "--   · 이벤트 월 파티션 표는 기본키에 파티션 시각 열 포함  · 등록자·수정자 FK 생략",
           "-- =============================================================================", ""]
    for t in tables.values():
        p = t["phys"]
        part = EVENT_PARTITIONS.get(p)
        body = []
        if part:
            body.append(f"    {p}_sequence_no BIGINT NOT NULL DEFAULT nextval('ksx.{p}_sequence_no_seq')")
        else:
            body.append(f"    {p}_sequence_no BIGINT GENERATED BY DEFAULT AS IDENTITY")
        for c in t["cols"]:
            nn = c["notnull"] or c["phys"] in t["pk"]
            body.append(f"    {c['phys']} {c['type']}{' NOT NULL' if nn else ''}")
        body += ["    " + x for x in TECH_DDL]
        body.append(f"    CONSTRAINT pk_{p} PRIMARY KEY ({', '.join(t['pk'])})")
        pre = f"CREATE SEQUENCE ksx.{p}_sequence_no_seq;\n" if part else ""
        tail = f" PARTITION BY RANGE ({part})" if part else ""
        out.append(f"{pre}CREATE TABLE ksx.{q(p)} ( -- {t['label']}\n" + ",\n".join(body) + f"\n){tail};")
        if not part:
            out.append(f"CREATE UNIQUE INDEX ux_{p}_sequence_no ON ksx.{q(p)} ({p}_sequence_no);")
    out += ["", "-- FK (관계목록 '물리')", fk_sql(tables, rels), "", "-- 논리 관계 (FK 아님 — SHACL·애플리케이션 검증)"]
    out += [f"--   {r['자식 테이블']}.{r['FK 컬럼']} → {r['부모 테이블']} [{r['관계 구분']}] {r['비고']}".rstrip() for r in logical]
    out += ["", comments(tables)]
    return "\n".join(out) + "\n"


def comments(tables):
    out = []
    for t in tables.values():
        out.append(f"COMMENT ON TABLE ksx.{q(t['phys'])} IS {lit(t['label'] + ' — ' + t['desc'])};")
        out.append(f"COMMENT ON COLUMN ksx.{q(t['phys'])}.{t['phys']}_sequence_no IS {lit(t['label'] + ' 일련번호(행 대리키, 표준 외 물리 컬럼)')};")
        for c in t["cols"]:
            out.append(f"COMMENT ON COLUMN ksx.{q(t['phys'])}.{c['phys']} IS {lit(c['label'])};")
    return "\n".join(out)


def spec_sql(tables):
    """V0014 가 표를 목표 모양으로 맞출 때 읽는 명세 (임시 표 두 개)."""
    tv = ",\n".join(f"  ({lit(t['phys'])}, {lit(t['label'])}, ARRAY[{', '.join(lit(x) for x in t['pk'])}]::text[], "
                    f"{'TRUE' if t['phys'] in EVENT_PARTITIONS else 'FALSE'})" for t in tables.values())
    cv = ",\n".join(f"  ({lit(t['phys'])}, {i}, {lit(c['phys'])}, {lit(c['type'])}, {'TRUE' if c['notnull'] or c['phys'] in t['pk'] else 'FALSE'})"
                    for t in tables.values() for i, c in enumerate(t["cols"], 1))
    return ("CREATE TEMP TABLE ksx_spec_table (tbl text PRIMARY KEY, label text, pk text[], partitioned boolean) ON COMMIT DROP;\n"
            f"INSERT INTO ksx_spec_table VALUES\n{tv};\n"
            "CREATE TEMP TABLE ksx_spec_col (tbl text, ord int, col text, typ text, req boolean, PRIMARY KEY (tbl, col)) ON COMMIT DROP;\n"
            f"INSERT INTO ksx_spec_col VALUES\n{cv};")


def seed_sql(tables):
    """onto·catalog 레지스트리 시드 (upsert). 링크는 표준 링크만 바꾼다(확장 링크는 둔다)."""
    import rdflib
    RDF, RDFS, OWL = rdflib.RDF, rdflib.RDFS, rdflib.OWL
    KS = rdflib.Namespace(KSX)
    model = json.load(open(os.path.join(ONT, "ontology_model.json"), encoding="utf-8"))
    g = rdflib.Graph().parse(os.path.join(ONT, "ksx9101_core.ttl"))
    gall = rdflib.Graph()
    for f in ("ksx9101_core.ttl", "arcon_ext.ttl", "lake_meta.ttl"):
        gall.parse(os.path.join(ONT, f))
    OURS = (KSX, ARCON, LAKE)

    def ours(x):
        return isinstance(x, rdflib.URIRef) and str(x).startswith(OURS) and not str(x).startswith(KSXV)

    def label_ko(x):
        return next((str(o) for o in gall.objects(x, RDFS.label) if getattr(o, "language", None) == "ko"), "")

    def local(x):
        return str(x).rsplit("/", 1)[1]

    def iri(curie):
        return curie.replace("ksx:", KSX).replace("arcon:", ARCON)

    sd = [f"INSERT INTO onto.ontology_version (version_id, ontology_iri, version_info, source, status) VALUES\n"
          f"  ('{VERSION_ID}', 'https://ontology.impix.co.kr/ksx9101', '9101-1:2025-v1.0-final/gen-0.3.0',"
          " 'KSX9101-1_2025_온톨로지용v1.0 (최종본) 테이블정의서·공통코드 워크시트 + arcon_ext.ttl + lake_meta.ttl', 'DRAFT')\n"
          "ON CONFLICT (version_id) DO NOTHING;"]
    rows, have = [], set()

    def parent_of(x):
        ps = sorted(str(o) for o in gall.objects(rdflib.URIRef(x), RDFS.subClassOf) if ours(o))
        return ps[0] if ps else None
    for c in model["classes"]:
        ci = iri(c["iri"])
        have.add(ci)
        rows.append((ci, c["name"], c["label"], c["group"], c["clause"] if c["clause"] != "—" else "", c["table"], c["pk"],
                     c["event"], True, c["definition"]))
    for x in sorted(set(gall.subjects(RDF.type, OWL.Class)), key=str):
        if not ours(x) or str(x) in have:
            continue
        have.add(str(x))
        grp = "표준 분류" if str(x).startswith(KSX) else ("기업 확장" if str(x).startswith(ARCON) else "레이크 메타")
        comment = next((str(o) for o in gall.objects(x, RDFS.comment)), "")
        rows.append((str(x), local(x), label_ko(x) or local(x), grp, "", "", "", False, str(x).startswith(KSX), comment))
    vals = []
    for (ci, name, label, grp, clause, table, pk, ev, std, dfn) in rows:
        par = parent_of(ci)
        par = par if par in have and par != ci else None
        vals.append(f"  ({lit(ci)}, {lit(name)}, {lit(label)}, {lit(grp)}, {lit(clause) if clause else 'NULL'}, "
                    f"{lit(table) if table else 'NULL'}, {lit(pk) if pk else 'NULL'}, {'TRUE' if ev else 'FALSE'}, "
                    f"{'TRUE' if std else 'FALSE'}, {lit(dfn)}, {lit(par) if par else 'NULL'}, '{VERSION_ID}')")
    sd.append("INSERT INTO onto.class (class_iri, local_name, label_ko, business_group, standard_clause, physical_table, primary_key, "
              "is_event, is_standard, definition_ko, parent_class_iri, version_id) VALUES\n" + ",\n".join(vals) +
              "\nON CONFLICT (class_iri) DO UPDATE SET local_name = EXCLUDED.local_name, label_ko = EXCLUDED.label_ko, "
              "business_group = EXCLUDED.business_group, standard_clause = EXCLUDED.standard_clause, physical_table = EXCLUDED.physical_table, "
              "primary_key = EXCLUDED.primary_key, is_event = EXCLUDED.is_event, is_standard = EXCLUDED.is_standard, "
              "definition_ko = EXCLUDED.definition_ko, parent_class_iri = EXCLUDED.parent_class_iri, version_id = EXCLUDED.version_id;\n")
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
    known = {r[0] for r in prow}
    for r in prow:
        if r[8] and r[8] not in known:
            r[8] = ""
    sd.append("INSERT INTO onto.property (property_iri, local_name, kind, label_ko, range_iri, code_scheme, source_attribute, is_transitive, super_property_iri, version_id) VALUES\n"
              + ",\n".join(f"  ({lit(a)}, {lit(b)}, {lit(c)}, {lit(d)}, {lit(e)}, {lit(f)}, {lit(h)}, {'TRUE' if t else 'FALSE'}, "
                           f"{lit(sp) if sp else 'NULL'}, '{VERSION_ID}')" for a, b, c, d, e, f, h, t, sp in prow)
              + "\nON CONFLICT (property_iri) DO UPDATE SET kind = EXCLUDED.kind, label_ko = EXCLUDED.label_ko, range_iri = EXCLUDED.range_iri, "
              "code_scheme = EXCLUDED.code_scheme, source_attribute = EXCLUDED.source_attribute, is_transitive = EXCLUDED.is_transitive, "
              "super_property_iri = EXCLUDED.super_property_iri, version_id = EXCLUDED.version_id;\n")
    lmerged = {}   # 같은 (주어, 속성, 목적어) 를 여러 FK 로 잇는 경우(입고/출고 창고 등)는 한 행으로 묶는다
    for l in model["links"]:
        key = (KSX + l["s"], KSX + l["p"], (ARCON if l["o"] in ("Location", "CustomerInstalledProduct") else KSX) + l["o"])
        m = lmerged.setdefault(key, {"fk": [], "kind": l["kind"]})
        m["fk"].append(", ".join(l["fk"]))
    lrow = [f"  ({lit(s_)}, {lit(p_)}, {lit(o_)}, {lit(' / '.join(m['fk'])[:300])}, {lit(m['kind'])})" for (s_, p_, o_), m in lmerged.items()]
    sd.append("DELETE FROM onto.link WHERE is_standard;   -- 표준 링크는 릴리스마다 통째로 바꾼다 (확장 링크는 그대로)")
    sd.append("INSERT INTO onto.link (subject_class_iri, property_iri, object_class_iri, fk_columns, relation_kind) VALUES\n"
              + ",\n".join(lrow) + "\nON CONFLICT (subject_class_iri, property_iri, object_class_iri) DO UPDATE SET "
              "fk_columns = EXCLUDED.fk_columns, relation_kind = EXCLUDED.relation_kind, is_standard = TRUE;\n")
    drow = [f"  ({lit('std.' + c['table'])}, {lit(c['label'])}, 'STANDARD', {lit(iri(c['iri']))}, "
            f"{lit('postgresql://lake/ksx.' + c['table'])}, 'table', 'batch', '9101-1:2025-v1.0-final', 'INTERNAL')" for c in model["classes"]]
    sd.append("INSERT INTO catalog.dataset (dataset_id, title_ko, zone_id, represents_class_iri, location_uri, format, ingest_mode, schema_version, sensitivity) VALUES\n"
              + ",\n".join(drow) + "\nON CONFLICT (dataset_id) DO UPDATE SET title_ko = EXCLUDED.title_ko, represents_class_iri = EXCLUDED.represents_class_iri, "
              "location_uri = EXCLUDED.location_uri, schema_version = EXCLUDED.schema_version;\n")
    basic = {"EnterpriseID": "refEnterprise", "SiteID": "refSite", "PlantID": "refPlant", "CreatorID": "createdBy", "ModifierID": "modifiedBy"}
    local2iri = {str(p).rsplit("/", 1)[1]: str(p) for p in g.subjects(RDF.type, None) if str(p).startswith(KSX)}
    linkprop = {}
    for l in model["links"]:
        lead = next((x for x in l["fk"] if x != "EnterpriseID"), l["fk"][0])
        linkprop.setdefault((l["s"], lead), KSX + l["p"])
    frow = []
    for t in tables.values():
        ds = "std." + t["phys"]
        frow.append(f"  ({lit(ds)}, {lit(t['phys'] + '_sequence_no')}, {lit(t['label'] + ' 일련번호')}, 'BIGINT', FALSE, TRUE, NULL, 'rule', 1.0, 'APPROVED')")
        for c in t["cols"]:
            a = c["attr"]
            if a in basic and c["std_type"] == "IDREF":
                piri = KSX + basic[a]
            elif (t["name"], a) in linkprop:
                piri = linkprop[(t["name"], a)]
            else:
                ln = re.sub(r"ID$", "Id", a[:1].lower() + a[1:])
                m = re.match(r"^([A-Z]+)(?=[A-Z][a-z]|$)", a)
                if m and len(m.group(1)) > 1:
                    ln = re.sub(r"ID$", "Id", m.group(1).lower() + a[len(m.group(1)):])
                piri = local2iri.get(ln, "")
            frow.append(f"  ({lit(ds)}, {lit(c['phys'])}, {lit(c['label'])}, {lit(c['type'])}, "
                        f"{'TRUE' if c['phys'] in t['uk'] else 'FALSE'}, {'TRUE' if c['notnull'] else 'FALSE'}, "
                        f"{lit(piri) if piri else 'NULL'}, 'rule', 1.0, 'APPROVED')")
        for fname, flabel, ftype, fprop in TECH_FIELDS:
            frow.append(f"  ({lit(ds)}, {lit(fname)}, {lit(flabel)}, {lit(ftype)}, FALSE, "
                        f"{'FALSE' if fname in ('lake_batch_id', 'lake_source_system', 'lake_record_hash') else 'TRUE'}, "
                        f"{lit(LAKE + fprop)}, 'rule', 1.0, 'APPROVED')")
    sd.append("INSERT INTO catalog.dataset_field (dataset_id, field_name, label_ko, data_type, is_pk, is_required, maps_to_property_iri, mapping_method, mapping_confidence, mapping_status) VALUES\n"
              + ",\n".join(frow) + "\nON CONFLICT (dataset_id, field_name) DO UPDATE SET label_ko = EXCLUDED.label_ko, data_type = EXCLUDED.data_type, "
              "is_pk = EXCLUDED.is_pk, is_required = EXCLUDED.is_required, maps_to_property_iri = EXCLUDED.maps_to_property_iri;\n")
    # 표준 데이터셋에서 사라진 필드(옮겨 간 헤더 열·없어진 식별자)는 지운다
    keep = ",\n".join(f"  ({lit('std.' + t['phys'])}, {lit(c)})" for t in tables.values()
                      for c in [t["phys"] + "_sequence_no"] + [x["phys"] for x in t["cols"]] + [f[0] for f in TECH_FIELDS])
    sd.append("DELETE FROM catalog.dataset_field f WHERE f.dataset_id LIKE 'std.%' AND (f.dataset_id, f.field_name) NOT IN (VALUES\n" + keep + ");")
    return "\n".join(sd) + "\n", len(prow), len(lrow), len(frow)


def main():
    tables = load()
    rels, logical = fks(tables)
    os.makedirs(os.path.join(ROOT, "db", "reference"), exist_ok=True)
    open(os.path.join(ROOT, "db", "reference", "ksx_target.sql"), "w", encoding="utf-8").write(target_ddl(tables, rels, logical))
    seed, n_prop, n_link, n_field = seed_sql(tables)
    tpl = open(os.path.join(ROOT, "tools", "V0014.template.sql"), encoding="utf-8").read()
    parts = {"SPEC": spec_sql(tables), "FK": fk_sql(tables, rels), "COMMENTS": comments(tables), "SEED": seed}
    for k, v in parts.items():
        assert f"-- @@{k}@@" in tpl, k
        tpl = tpl.replace(f"-- @@{k}@@", f"-- ↓ 생성: tools/gen_schema.py ({k})\n{v}\n-- ↑ 생성 끝 ({k})")
    open(os.path.join(ROOT, "db", "schema", "V0014__ksx9101_v1_final.sql"), "w", encoding="utf-8").write(tpl)
    print(f"tables={len(tables)} columns={sum(len(t['cols']) + 1 for t in tables.values())} fk={len(rels)} "
          f"logical={len(logical)} props={n_prop} links={n_link} fields={n_field}")


if __name__ == "__main__":
    sys.exit(main())
