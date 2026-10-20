#!/usr/bin/env python3
"""KS X 9101-1:2025 테이블정의서(TSV 추출본) → 온톨로지 산출물 생성기.

입력 : source_extracts/tabdef_*.tsv, code_*.tsv
출력 : ontology/ksx9101_core.ttl      (T-Box: 클래스·데이터속성·객체속성)
       ontology/ksx9101_shapes.ttl    (SHACL 적합성 셰이프)
       ontology/ksx9101_codelists.ttl (SKOS 코드리스트 + 단위)
       ontology/class_catalog.csv     (클래스 목록)
       ontology/link_catalog.csv      (객체속성=관계 목록)
       ontology/ontology_model.json   (목업·DDL 시드용 요약)

원칙 (설계서 §3 참조)
- 명사 1개 = owl:Class 1개. 업무영역 9개를 상위 클래스로 둔다.
- 속성은 전역 1개로 선언하고 rdfs:domain 을 걸지 않는다. 어느 클래스에서 쓰는지는
  SHACL(sh:property)과 ksx:usedIn 주석으로 표현한다. (domain 추론 오염 방지)
- 참조속성(IDREF "대상")은 관계목록의 FK 1건 = owl:ObjectProperty 사용 1건.
- enum 속성은 skos:Concept 를 가리키는 ObjectProperty, 코드그룹은 skos:ConceptScheme.
- 표준 외 요소(헤더 보조 테이블, 계보 전이 속성 등)는 arcon: 네임스페이스로 분리.
"""
import csv, json, os, re
from ksxnames import snake
from collections import defaultdict, OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "source_extracts")
OUT = os.path.join(ROOT, "ontology")

KSX = "https://ontology.impix.co.kr/ksx9101/"
ARCON = "https://ontology.impix.co.kr/arcon/"
CODE = "https://data.impix.co.kr/arcon/codelist/"

GROUPS = OrderedDict([
    ("기준정보", ("MasterDataObject", "Master data")),
    ("프로젝트관리", ("ProjectObject", "Project management")),
    ("판매관리", ("SalesObject", "Sales management")),
    ("구매관리", ("PurchaseObject", "Purchase management")),
    ("자재관리", ("MaterialObject", "Material management")),
    ("생산관리", ("ProductionObject", "Production management")),
    ("재고관리", ("InventoryObject", "Inventory management")),
    ("창고관리", ("WarehouseObject", "Warehouse management")),
    ("서비스관리", ("ServiceObject", "Service management")),
])
# 헤더·라인 구조 명사 (7.1, v1.0 최종본): 명사 1개 = 헤더 테이블 + 라인 테이블. 둘 다 표준(ksx:)이다.
HL_NOUNS = ["UOMGroup", "BOM", "Routing", "WarehouseLocation", "SalesOrder", "PurchaseOrder",
            "ProductReleaseRequest", "Delivery"]
HEADER_TABLES = {n + "Header" for n in HL_NOUNS}
LINE_TABLES = {n + "Line" for n in HL_NOUNS}
# 사건(Event)형 명사 — 설계서 §3.3
EVENT_NOUNS = {"OperationStart", "OperationEnd", "TransferStart", "TransferEnd", "InTransitLocation",
               "EquipmentState", "Alarm", "TraceParameter", "ProductTraceParameterOnCustomer"}
# 문서 행: 헤더·라인의 라인 + 식별자(문서)+순번으로 행을 구분하는 명사 (해설 6.3)
DOC_LINE_NOUNS = LINE_TABLES | {"GoodsReceipt", "ProductIncoming", "ProductRelease", "Return", "ProductionPerformance"}
# 외부 표준 정렬 (부속서 B)
ALIGN = {
    "Site": "IEC62264:Site", "WorkCalendar": "IEC62264:WorkCalendar", "Lot": "IEC62264:MaterialLot",
    "Equipment": "IEC62264:Equipment", "ProductionPlanning": "IEC62264:ProductionSchedule",
    "AvailableInventory": "IEC62264:AvailableInventory", "Line": "IEC62264:WorkCenter",
    "Enterprise": "IEC62264:Enterprise", "ProductionPerformance": "IEC62264:SegmentResponse",
    "ProductionPerformanceItem": "IEC62264:MaterialActual",
    "ProductionPerformancePersonnel": "IEC62264:PersonnelActual",
    "ProductionPerformanceEquipment": "IEC62264:EquipmentActual",
    "ProductionPerformanceQuality": "IEC62264:SegmentData", "Batch": "IEC61512-1:Batch",
    "Personnel": "OAGIS:PersonLabor", "ItemMaster": "OAGIS:ItemMaster", "BOMHeader": "OAGIS:BillOfMaterial",
    "RoutingHeader": "OAGIS:Routing", "SalesOrderHeader": "OAGIS:SalesOrder", "PurchaseOrderHeader": "OAGIS:PurchaseOrder",
    "GoodsReceipt": "OAGIS:ReceiveDelivery", "GoodsIssue": "OAGIS:IssueInventory",
    "ProductionOrder": "OAGIS:ProductionOrder", "SupplierInspectionResult": "OAGIS:TestResult",
    "StockTransfer": "OAGIS:MoveInventory", "InventoryCount": "OAGIS:InventoryCount",
    "ProductReleaseRequestHeader": "OAGIS:ShipmentRequest", "ProductRelease": "OAGIS:Shipment",
    "DeliveryHeader": "OAGIS:DeliveryReceipt",
    "Carrier": "SEMI:Carrier", "OperationStart": "SEMI:ProcessingStarted",
    "OperationEnd": "SEMI:ProcessingCompleted", "TransferCommand": "SEMI:TransferCommand",
    "TransferStart": "SEMI:TransferInitiated", "TransferEnd": "SEMI:TransferCompleted",
    "EquipmentState": "SEMI:EquipmentState", "Alarm": "SEMI:AlarmReport",
}
XSD = {"string": "xsd:string", "int": "xsd:integer", "float": "xsd:decimal", "date": "xsd:date",
       "dateTime": "xsd:dateTime", "boolean": "xsd:boolean", "duration": "xsd:duration", "ID": "xsd:string"}
BASIC_REF = {  # 기본 속성 참조 → 공용 객체속성 5개
    "EnterpriseID": ("refEnterprise", "Enterprise", "회사 참조"),
    "SiteID": ("refSite", "Site", "사업장 참조"),
    "PlantID": ("refPlant", "Plant", "공장 참조"),
    "CreatorID": ("createdBy", "Personnel", "등록자"),
    "ModifierID": ("modifiedBy", "Personnel", "수정자"),
}


# 원천 컬럼 어간이 대상 명사를 드러내지 않는 경우의 이름 보정
RENAME = {"SalesDocument": "SalesOrder", "PurchaseDocument": "PurchaseOrder",
          "Request": "AfterSalesServiceRequest", "ParentCommonCodeGroup": "ParentCommonCode"}


def tsv(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def lc(s):
    """PascalCase → camelCase (선행 약어 보존: BOMID→bomId, UOMCode→uomCode)."""
    m = re.match(r"^([A-Z]+)(?=[A-Z][a-z]|$)", s)
    if m and len(m.group(1)) > 1:
        head = m.group(1)
        return head.lower() + s[len(head):]
    return s[:1].lower() + s[1:]


def norm(attr):
    """ItemID → itemId, BOMRevisionNumber → bomRevisionNumber."""
    s = lc(attr)
    return re.sub(r"ID$", "Id", s)


def ref_stem(col):
    for suf in ("ID", "Number"):
        if col.endswith(suf) and len(col) > len(suf):
            return col[: -len(suf)]
    return col


def esc(s):
    return (s or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").strip()


def cls_iri(name):
    return "ksx:" + name


def noun_ref(stem, parent):
    """참조 속성 이름: 헤더를 가리키면 명사 이름(refPurchaseOrder), 라인을 가리키면 +Line(refPurchaseOrderLine)."""
    for n in HL_NOUNS:
        if parent == n + "Header":
            return "ref" + n
        if parent == n + "Line":
            return "ref" + n + "Line"
    return "ref" + RENAME.get(stem, stem)


def main():
    tables = tsv("tabdef_02_테이블목록.tsv")
    cols = tsv("tabdef_01_테이블정의서.tsv")
    rels = tsv("tabdef_03_관계목록.tsv")
    groups = tsv("code_01_코드그룹목록.tsv")
    codes = tsv("code_02_공통코드.tsv")
    uoms = tsv("code_03_단위코드.tsv")
    # 빈 행·주석 행 제외, None → ""
    clean = lambda rows, key: [{k: (v or "") for k, v in r.items()} for r in rows if r.get(key)]
    groups = clean(groups, "공통코드그룹 / (CommonCodeGroup)")
    codes = clean(codes, "공통코드식별자 / (CommonCodeID)")
    uoms = clean(uoms, "단위코드 / (UOMCode)")

    tinfo = OrderedDict()
    for t in tables:
        if t["테이블명(영문)"]:          # 합계 행 제외
            tinfo[t["테이블명(영문)"]] = t
    tcols = defaultdict(list)
    for c in cols:
        if c["구분"] == "PK":         # 행 일련번호(대리키, 표준 외 물리 컬럼) — 온톨로지에 올리지 않는다
            continue
        tcols[c["테이블명(영문)"]].append(c)

    # ---- 관계(객체속성) 도출 -------------------------------------------------
    links = []          # (child, prop, parent, fk_cols, kind, note)
    ref_cols = defaultdict(set)   # child → 참조 대표 컬럼(객체속성으로 승격된 컬럼)
    prop_range = defaultdict(set)
    header_props = set()          # 라인 → 자기 헤더 참조 (ksx:hasHeader 하위 속성)
    copy_of = {}                  # (child, attr) → 원천 "명사.속성" (사본 속성, 7.1)
    for r in rels:
        kind = r["관계 구분"]
        child, parent = r["자식 테이블"], r["부모 테이블"]
        fk = [x.strip() for x in r["FK 컬럼"].split(",")]
        if kind == "기본 속성" or not child:
            continue
        lead = next((x for x in fk if x != "EnterpriseID"), fk[0])
        if kind == "사본 참조":
            m = re.search(r"원천 속성 ([A-Za-z]+\.[A-Za-z]+)", r["비고"])
            copy_of[(child, lead)] = m.group(1) if m else parent
            continue
        if kind == "다형 참조":
            links.append(dict(child=child, prop="ref" + ref_stem(lead), parent="arcon:Location",
                              fk=fk, kind=kind, note=r["비고"]))
            ref_cols[child].add(lead)
            continue
        if kind == "표준 외 대상":
            links.append(dict(child=child, prop="refCustomerInstalledProduct",
                              parent="arcon:CustomerInstalledProduct", fk=fk, kind=kind, note=r["비고"]))
            continue
        prop = noun_ref(ref_stem(lead), parent)
        links.append(dict(child=child, prop=prop, parent=cls_iri(parent), fk=fk, kind=kind, note=r["비고"]))
        ref_cols[child].add(lead)
        prop_range[prop].add(cls_iri(parent))
        if kind == "헤더-라인":
            header_props.add(prop)

    # 같은 이름이 서로 다른 범위를 가리키면 부모명으로 구분
    clash = {p for p, rs in prop_range.items() if len(rs) > 1}
    for l in links:
        if l["prop"] in clash:
            l["prop"] = l["prop"] + "_" + l["parent"].split(":")[1]

    # ---- 데이터속성 / 코드속성 ------------------------------------------------
    dprops = OrderedDict()   # name → dict(range, label, comp, usedIn set)
    cprops = OrderedDict()   # code(enum) props → dict(scheme, label, usedIn)
    for t, cl in tcols.items():
        for c in cl:
            a, typ = c["컬럼명(영문)"], c["데이터 타입(표준)"]
            if (a in BASIC_REF and typ == "IDREF") or a in ref_cols[t]:
                continue
            if typ == "IDREF" and c["FK 참조(테이블.컬럼)"] and a not in ref_cols[t]:
                # 복합키의 보조 컬럼(순번 등)이 IDREF 로 표기된 경우 → 데이터속성 처리
                pass
            name = norm(a)
            if typ == "enum":
                cref = c["코드 참조"]
                scheme = cref.split("=", 1)[1] if "=" in cref else ("UOM" if "UOMGroup" in cref else a)
                p = cprops.setdefault(name, dict(scheme=set(), label=c["속성명(국문)"], used=set(), attr=a))
                p["scheme"].add(scheme)
                p["used"].add(t)
            else:
                rng = XSD.get(typ, "xsd:string")
                p = dprops.setdefault(name, dict(range=rng, label=c["속성명(국문)"], used=set(), attr=a,
                                                 ident=(typ == "ID")))
                p["used"].add(t)
                if (t, a) in copy_of:
                    p.setdefault("copy", set()).add(copy_of[(t, a)])

    os.makedirs(OUT, exist_ok=True)
    W = []
    w = W.append
    w("""@prefix ksx:   <%s> .
@prefix arcon: <%s> .
@prefix owl:   <http://www.w3.org/2002/07/owl#> .
@prefix rdf:   <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs:  <http://www.w3.org/2000/01/rdf-schema#> .
@prefix skos:  <http://www.w3.org/2004/02/skos/core#> .
@prefix xsd:   <http://www.w3.org/2001/XMLSchema#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
""" % (KSX, ARCON))
    w("""<https://ontology.impix.co.kr/ksx9101> a owl:Ontology ;
    rdfs:label "KS X 9101-1:2025 제조업무데이터 교환 코어 온톨로지"@ko ;
    owl:versionInfo "9101-1:2025-v1.0-final/gen-0.3.0" ;
    dcterms:source "KSX9101-1_2025_온톨로지용v1.0_테이블정의서.xlsx" ;
    rdfs:comment "tools/gen_ontology.py 로 기계 생성. 수기 편집 금지. 표준 본문은 전재하지 않고 명칭·타입·절 번호만 기록."@ko .

### 메타 주석 속성
ksx:standardClause a owl:AnnotationProperty ; rdfs:label "표준 조항"@ko .
ksx:standardTable  a owl:AnnotationProperty ; rdfs:label "표준 표 번호"@ko .
ksx:physicalTable  a owl:AnnotationProperty ; rdfs:label "물리 테이블명"@ko .
ksx:primaryKey     a owl:AnnotationProperty ; rdfs:label "식별 키(UK, 회사+식별 속성)"@ko .
ksx:copyOf         a owl:AnnotationProperty ; rdfs:label "사본 속성의 원천(명사.속성)"@ko .
ksx:sourceAttribute a owl:AnnotationProperty ; rdfs:label "원천 속성명"@ko .
ksx:usedIn         a owl:AnnotationProperty ; rdfs:label "사용 명사"@ko .
ksx:codeScheme     a owl:AnnotationProperty ; rdfs:label "공통코드그룹"@ko .
ksx:alignedTo      a owl:AnnotationProperty ; rdfs:label "외부 표준 대응"@ko .

### 최상위 · 업무영역
ksx:ManufacturingBusinessObject a owl:Class ;
    rdfs:label "제조업무객체"@ko , "Manufacturing business object"@en ;
    rdfs:comment "KS X 9101-1 7.3 기본 속성을 갖는 모든 명사의 최상위 클래스"@ko .
""")
    for g, (cn, en) in GROUPS.items():
        w(f'ksx:{cn} a owl:Class ; rdfs:subClassOf ksx:ManufacturingBusinessObject ;\n'
          f'    rdfs:label "{g}"@ko , "{en}"@en .')
    w("""
### 교차 분류 (표준 외 · arcon)
arcon:Event a owl:Class ; rdfs:subClassOf ksx:ManufacturingBusinessObject ;
    rdfs:label "제조 이벤트"@ko ; rdfs:comment "상태가 아니라 시점에 발생한 사건. 타임라인·인과 추적의 단위."@ko .
arcon:eventTime a owl:DatatypeProperty ; rdfs:range xsd:dateTime ; rdfs:label "이벤트 시각"@ko .
arcon:DocumentLine a owl:Class ; rdfs:label "문서 행(헤더·라인 구조)"@ko ;
    rdfs:comment "2025 개정 6.3: 문서 단위 식별자 + 행 순번으로 식별하는 명사"@ko .
arcon:DocumentHeader a owl:Class ; rdfs:label "헤더 구조체"@ko ;
    rdfs:comment "7.1 헤더(Header)·라인(Line) 구조: 명사 1건에 1회 나타나며 명사의 식별 속성을 가진다"@ko .
arcon:Location a owl:Class ; rdfs:label "위치(다형)"@ko ;
    rdfs:comment "이동 출발지·목적지. 공정·설비·저장소·캐리어 중 하나 — 유형 코드로 구분"@ko .
arcon:CustomerInstalledProduct a owl:Class ; rdfs:subClassOf ksx:ServiceObject ;
    rdfs:label "고객 설치 제품"@ko ; rdfs:comment "제조번호(SerialNumber) 단위. 표준 외 확장 명사(KS X 9101-2 절차로 등록 예정)"@ko .
ksx:hasHeader a owl:ObjectProperty ; rdfs:range arcon:DocumentHeader ; rdfs:label "소속 헤더(7.1 헤더·라인)"@ko .
arcon:derivedFrom a owl:ObjectProperty , owl:TransitiveProperty ;
    rdfs:label "계보 파생"@ko ; rdfs:comment "로트 분할·병합 계보의 전이 폐포. 전수 역추적 근거."@ko .
arcon:componentOf a owl:ObjectProperty , owl:TransitiveProperty ;
    rdfs:label "구성품(다단 BOM)"@ko .
""")
    # 클래스
    w("### 명사 → 클래스")
    catalog = []
    for t, ti in tinfo.items():
        g = ti["업무영역"]
        sup = [f"ksx:{GROUPS[g][0]}"]
        if t in HEADER_TABLES:
            sup = ["arcon:DocumentHeader", f"ksx:{GROUPS[g][0]}"]
        if t in EVENT_NOUNS:
            sup.append("arcon:Event")
        if t in DOC_LINE_NOUNS:
            sup.append("arcon:DocumentLine")
        # 생산실적투입품목·인력·설비·품질은 생산실적의 "부분"이지 "종류"가 아니다
        # → subClassOf 가 아니라 ksx:refProductionPerformance 관계로만 연결한다.
        iri = cls_iri(t)
        lines = [f"{iri} a owl:Class ;", f"    rdfs:subClassOf {', '.join(sup)} ;",
                 f'    rdfs:label "{esc(ti["테이블명(국문)"])}"@ko , "{t}"@en ;',
                 f'    skos:definition "{esc(ti["테이블 설명(표준 정의)"])}"@ko ;',
                 f'    ksx:physicalTable "{snake(t)}" ;',
                 f'    ksx:primaryKey "{esc(ti["UK(식별 키)"])}"']
        if ti["조항"] and ti["조항"] != "—":
            lines[-1] += " ;"
            lines.append(f'    ksx:standardClause "{ti["조항"]}" ; ksx:standardTable "표 {ti["표"]}"')
        if t in ALIGN:
            lines[-1] += " ;"
            lines.append(f'    ksx:alignedTo "{ALIGN[t]}"')
        w("\n".join(lines) + " .\n")
        catalog.append(dict(name=t, iri=iri, label=ti["테이블명(국문)"], group=g,
                            table=snake(t), clause=ti["조항"], pk=ti["UK(식별 키)"],
                            columns=int(ti["컬럼 수"] or 0) - 1, event=t in EVENT_NOUNS,
                            definition=ti["테이블 설명(표준 정의)"]))
    # 기본 참조 속성
    w("### 기본 속성(7.3) 참조 → 공용 객체속성")
    for a, (p, rng, lab) in BASIC_REF.items():
        w(f'ksx:{p} a owl:ObjectProperty ; rdfs:range ksx:{rng} ; rdfs:label "{lab}"@ko ; ksx:sourceAttribute "{a}" .')
    w('ksx:creationDateTime a owl:DatatypeProperty ; rdfs:range xsd:dateTime ; rdfs:label "등록일시"@ko .')
    w('ksx:modificationDateTime a owl:DatatypeProperty ; rdfs:range xsd:dateTime ; rdfs:label "수정일시"@ko .')
    w('ksx:note a owl:DatatypeProperty ; rdfs:range xsd:string ; rdfs:label "비고"@ko .\n')

    # 객체속성 (명사 참조)
    w("### 참조속성(IDREF) → 객체속성")
    byprop = OrderedDict()
    for l in links:
        if l["prop"].startswith("arcon:"):
            continue
        byprop.setdefault(l["prop"], []).append(l)
    for p, ls in byprop.items():
        rng = sorted({l["parent"] for l in ls})
        used = sorted({l["child"] for l in ls})
        src = ls[0]["fk"]
        lead = next((x for x in src if x != "EnterpriseID"), src[0])
        extra = ""
        if p == "refParentLot":
            extra = " ;\n    rdfs:subPropertyOf arcon:derivedFrom"
        if p == "refChildItem":
            extra = " ;\n    rdfs:subPropertyOf arcon:componentOf"
        if p in header_props:
            extra += " ;\n    rdfs:subPropertyOf ksx:hasHeader"
        w(f'ksx:{p} a owl:ObjectProperty ;\n    rdfs:range {rng[0]} ;\n'
          f'    rdfs:label "{esc(next((c["속성명(국문)"] for c in tcols[ls[0]["child"]] if c["컬럼명(영문)"]==lead), lead))} 참조"@ko ;\n'
          f'    ksx:sourceAttribute "{lead}" ;\n    ksx:usedIn "{", ".join(used)}"{extra} .')
    w("")
    # 코드 속성
    w("### enum 속성 → SKOS 개념 참조")
    for p, d in cprops.items():
        w(f'ksx:{p} a owl:ObjectProperty ; rdfs:range skos:Concept ;\n'
          f'    rdfs:label "{esc(d["label"])}"@ko ; ksx:sourceAttribute "{d["attr"]}" ;\n'
          f'    ksx:codeScheme "{", ".join(sorted(d["scheme"]))}" ; ksx:usedIn "{", ".join(sorted(d["used"]))}" .')
    w("")
    w("### 값 속성 → 데이터속성")
    for p, d in dprops.items():
        cp = f' ;\n    ksx:copyOf "{", ".join(sorted(d["copy"]))}"' if d.get("copy") else ""
        w(f'ksx:{p} a owl:DatatypeProperty ; rdfs:range {d["range"]} ;\n'
          f'    rdfs:label "{esc(d["label"])}"@ko ; ksx:sourceAttribute "{d["attr"]}" ; ksx:usedIn "{", ".join(sorted(d["used"]))}"{cp} .')
    # 이벤트 시각 상위속성
    for p in ("operationStartTime", "operationEndTime", "eventDateTime", "collectionDateTime"):
        if p in dprops:
            w(f"ksx:{p} rdfs:subPropertyOf arcon:eventTime .")
    open(os.path.join(OUT, "ksx9101_core.ttl"), "w", encoding="utf-8").write("\n".join(W) + "\n")

    # ---- SHACL ---------------------------------------------------------------
    S = ["""@prefix ksx:   <%s> .
@prefix arcon: <%s> .
@prefix sh:    <http://www.w3.org/ns/shacl#> .
@prefix skos:  <http://www.w3.org/2004/02/skos/core#> .
@prefix xsd:   <http://www.w3.org/2001/XMLSchema#> .
@prefix rdfs:  <http://www.w3.org/2000/01/rdf-schema#> .
# KS X 9101-1:2025 적합성 셰이프 — gen_ontology.py 기계 생성
# 차원: [구조] 필수·카디널리티 / [값] 데이터타입 / [관계] 참조 대상 클래스 / [의미] 코드 개념
""" % (KSX, ARCON)]
    linkmap = defaultdict(list)
    for l in links:
        linkmap[l["child"]].append(l)
    for t, cl in tcols.items():
        iri = cls_iri(t)
        props = []
        for a, (p, rng, lab) in BASIC_REF.items():
            # 회사·사업장·공장은 자기 식별자(ID)가 기본 속성을 갈음 → 참조 제약에서 제외
            if any(c["컬럼명(영문)"] == a and c["데이터 타입(표준)"] == "IDREF" for c in cl):
                req = a in ("EnterpriseID", "SiteID", "PlantID")
                props.append(f'[ sh:path ksx:{p} ; sh:class ksx:{rng} ; sh:maxCount 1 ;'
                             + (f' sh:minCount 1 ; sh:message "[KSX9101/구조] {a} 는 필수(7.3)" ' if req else "") + "]")
        seen = set()
        for c in cl:
            a, typ = c["컬럼명(영문)"], c["데이터 타입(표준)"]
            if (a in BASIC_REF and typ == "IDREF") or a in ref_cols[t] or a in seen:
                continue
            seen.add(a)
            name = norm(a)
            req = c["NOT NULL"] == "Y"
            mc = f' sh:minCount 1 ; sh:message "[KSX9101/구조] {a} NOT NULL" ;' if req else ""
            if typ == "enum":
                props.append(f'[ sh:path ksx:{name} ; sh:class skos:Concept ; sh:maxCount 1 ;{mc} ]')
            else:
                props.append(f'[ sh:path ksx:{name} ; sh:datatype {XSD.get(typ, "xsd:string")} ; sh:maxCount 1 ;{mc} ]')
        for l in linkmap[t]:
            p = l["prop"] if l["prop"].startswith("arcon:") else "ksx:" + l["prop"]
            if l["kind"] in ("다형 참조", "표준 외 대상", "헤더 경유 참조"):
                continue
            props.append(f'[ sh:path {p} ; sh:class {l["parent"]} ; sh:message "[KSX9101/관계] {",".join(l["fk"])} → {l["parent"]}" ]')
        S.append(f"{iri}Shape a sh:NodeShape ;\n    sh:targetClass {iri} ;\n    sh:property\n        "
                 + " ,\n        ".join(props) + " .\n")
    open(os.path.join(OUT, "ksx9101_shapes.ttl"), "w", encoding="utf-8").write("\n".join(S))

    # ---- SKOS 코드리스트 -------------------------------------------------------
    K = ["""@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix cl:   <%s> .
@prefix ksx:  <%s> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
# 공통코드 워크시트 → SKOS (코드그룹=ConceptScheme, 코드=Concept, 상위코드=skos:broader)
""" % (CODE, KSX)]
    gkey = "공통코드그룹 / (CommonCodeGroup)"
    for g in groups:
        K.append(f'<{CODE}{g[gkey]}> a skos:ConceptScheme ; skos:prefLabel "{esc(g["그룹명"])}"@ko ;\n'
                 f'    skos:definition "{esc(g["그룹 설명"])}"@ko ; ksx:codeSystem "{esc(g["코드체계"])}" .')
    for c in codes:
        gid = c[gkey]
        cid = re.sub(r"[^A-Za-z0-9_\-\.]", "_", c["공통코드식별자 / (CommonCodeID)"])
        line = (f'<{CODE}{gid}/{cid}> a skos:Concept ; skos:inScheme <{CODE}{gid}> ; skos:notation "{esc(c["공통코드식별자 / (CommonCodeID)"])}" ;\n'
                f'    skos:prefLabel "{esc(c["공통코드명 / (CommonCodeName)"])}"@ko')
        if c["영문명"]:
            line += f' , "{esc(c["영문명"])}"@en'
        pg, pc = c["상위공통코드그룹 / (ParentCommonCodeGroup)"], c["상위공통코드식별자 / (ParentCommonCodeID)"]
        if pg and pc:
            line += f' ;\n    skos:broader <{CODE}{pg}/{re.sub(r"[^A-Za-z0-9_.-]", "_", pc)}>'
        K.append(line + " .")
    K.append(f'\n<{CODE}UOM> a skos:ConceptScheme ; skos:prefLabel "단위코드"@ko .')
    for u in uoms:
        uc = re.sub(r"[^A-Za-z0-9_.-]", "_", u["단위코드 / (UOMCode)"]) or "X"
        K.append(f'<{CODE}UOM/{uc}> a skos:Concept ; skos:inScheme <{CODE}UOM> ; skos:notation "{esc(u["단위코드 / (UOMCode)"])}" ;\n'
                 f'    skos:prefLabel "{esc(u["단위코드명 / (UOMCodeName)"])}"@ko ; ksx:uneceRec20 "{esc(u["UN/CEFACT / Rec 20"])}" ;\n'
                 f'    rdfs:comment "그룹 {esc(u["단위그룹식별자 / (UOMGroupID)"])}, 환산계수 {esc(u["기준단위 환산계수"])}" .')
    open(os.path.join(OUT, "ksx9101_codelists.ttl"), "w", encoding="utf-8").write("\n".join(K) + "\n")

    # ---- CSV / JSON ----------------------------------------------------------
    with open(os.path.join(OUT, "class_catalog.csv"), "w", encoding="utf-8-sig", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(["클래스 IRI", "국문", "업무영역", "물리 테이블", "조항", "PK", "컬럼 수", "이벤트형", "나가는 관계 수"])
        for c in catalog:
            wr.writerow([c["iri"], c["label"], c["group"], c["table"], c["clause"], c["pk"], c["columns"],
                         "Y" if c["event"] else "", len(linkmap[c["name"]])])
    with open(os.path.join(OUT, "link_catalog.csv"), "w", encoding="utf-8-sig", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(["주어 클래스", "객체속성", "목적어 클래스", "FK 컬럼", "관계 구분", "비고"])
        for l in links:
            p = l["prop"] if l["prop"].startswith("arcon:") else "ksx:" + l["prop"]
            wr.writerow([cls_iri(l["child"]), p, l["parent"], ", ".join(l["fk"]), l["kind"], l["note"]])
    model = dict(classes=catalog,
                 links=[dict(s=l["child"], p=l["prop"], o=l["parent"].split(":")[1], kind=l["kind"],
                             fk=l["fk"]) for l in links],
                 counts=dict(classes=len(catalog), objectProperties=len(byprop) + 5,
                             codeProperties=len(cprops), datatypeProperties=len(dprops) + 3,
                             links=len(links), codeSchemes=len(groups) + 1, concepts=len(codes) + len(uoms)))
    json.dump(model, open(os.path.join(OUT, "ontology_model.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(json.dumps(model["counts"], ensure_ascii=False))


if __name__ == "__main__":
    main()
