# 1단계 · 온톨로지 설계서 — KS X 9101 기반 제조 온톨로지 + 데이터레이크 메타 온톨로지

작성 2026-10-14 · 버전 0.1 (초안)
기반 자료: 아크온 지식그래프 설계서 V1·V2(arcon-kg.a2lab.co.kr), KSX9101-1_2025 온톨로지용 v1.0 테이블정의서·공통코드 워크시트, 제조 온톨로지 설계 지침서·구축 방안, E2E 보고서, CKD 점검 리포트, 입찰 공고 7건, SCM 리스크 추론 영상(김학래)

---

## 1. 이 설계가 정하는 것

아크온 V2 설계서는 "KS X 9101 을 RDF/OWL 로 컴파일하면 그것이 곧 온톨로지 코어"라는 방향을 이미 세웠다. 이번 1단계는 그 방향을 **2025 개정 v1.0 테이블정의서(명사 67 + 헤더 보조 3 = 70 테이블, 1,432 컬럼)** 로 실제 생성해 보고, 데이터레이크를 위한 **메타 온톨로지(lake:)** 를 새로 얹는다.

| 층 | 네임스페이스 | 파일 | 내용 | 변경 주기 |
|---|---|---|---|---|
| 표준 코어 | `ksx:` | `ksx9101_core.ttl` | 클래스 70 · 객체속성 68 · 코드속성 90 · 데이터속성 321 | 표준 개정 시 (생성기 재실행) |
| 적합성 셰이프 | `ksx:*Shape` | `ksx9101_shapes.ttl` | NodeShape 70 (구조·값·관계 3차원) | 코어와 동시 생성 |
| 코드·단위 | `cl:` | `ksx9101_codelists.ttl` | ConceptScheme 79 · Concept 608 (공통코드 561 + 단위 48) | 회사 코드 셋업 시 |
| 기업 확장 | `arcon:` · `ksxv:` | `arcon_ext.ttl` | 동사 12 · 비즈니스 액션 · 리스크 이벤트 · KPI · 유지보수 · 인과 | 수시 |
| 레이크 메타 | `lake:` | `lake_meta.ttl` | 존 · 데이터셋 · 계보 · 근거 등급 · 품질 · 접근 · AI 자산 | 플랫폼 버전 |

`ksx9101_core.ttl` · `ksx9101_shapes.ttl` · `ksx9101_codelists.ttl` 은 **손으로 쓰지 않았다.** `tools/gen_ontology.py` 가 테이블정의서 추출본(`source_extracts/`)에서 생성한다. 원칙 3(생성 > 작성)을 그대로 따른 것이다.

![핵심 클래스와 관계](ontology_diagram.svg)

---

## 2. 클래스 설계

### 2.1 계층

```
ksx:ManufacturingBusinessObject          ← 기본 속성 7.3 을 가진 모든 명사
 ├─ ksx:MasterDataObject (기준정보 24)    ├─ ksx:ProductionObject (생산관리 24)
 ├─ ksx:ProjectObject (2)                 ├─ ksx:InventoryObject (4)
 ├─ ksx:SalesObject (2)                   ├─ ksx:WarehouseObject (4)
 ├─ ksx:PurchaseObject (3)                └─ ksx:ServiceObject (4)
 └─ ksx:MaterialObject (3)
교차 분류 (arcon:, 다중 상속)
 ├─ arcon:Event          착공·완공·운행시작·운행완료·운송위치·알람·설비파라미터이력·고객제품데이터 (8)
 ├─ arcon:DocumentLine   헤더·라인 구조 명사 8 (BOM·Routing·입고·제품입고·출하의뢰·제품출고·반품·생산실적)
 └─ arcon:DocumentHeader BOMHeader · RoutingHeader · ProductReleaseRequestHeader (표준 외 보조 3)
```

| 업무영역 | 수 | 클래스 |
|---|---|---|
| 기준정보 | 24 | 사업장 Site, 공장 Plant, 부서 Department, 사원 Personnel, 고객사 CustomerPartyMaster, 공급사 VendorPartyMaster, 공통코드정보 CommonCodeMaster, 달력 WorkCalendar, 단위그룹 UOMGroup, 품목마스터 ItemMaster, 자재명세서 BOM, *자재명세서헤더 BOMHeader*, 로트 Lot, 공정경로 Routing, *공정경로헤더 RoutingHeader*, 공정 Operation, 설비 Equipment, 공정설비 OperationEquipment, 캐리어 Carrier, 저장소재공정보 StockerInventory, 창고 WarehouseLocation, 배치 Batch, 라인 Line, 회사 Enterprise |
| 프로젝트관리 | 2 | 프로젝트마스터 ProjectMaster, 설계변경지시 EngineeringChangeOrder |
| 판매관리 | 2 | 수주오더 SalesOrder, 판매계획 SalesPlan |
| 구매관리 | 3 | 기준가격 BasePrice, 구매요청 PurchaseRequisition, 구매발주 PurchaseOrder |
| 자재관리 | 3 | 자재도착 MaterialArrival, 입고 GoodsReceipt, 자재불출 GoodsIssue |
| 생산관리 | 24 | 생산계획, 생산지시, 착공, 완공, 이동지시, 운행시작, 운행완료, 운송위치, 설비상태, 알람, 협력업체품질검사 계획·신청·결과, 시정조치 요청·계획·결과, 제품포장, 설비파라미터, 설비파라미터이력, 생산실적, 생산실적투입품목·투입인력, 설비활용실적, 생산품질실적 |
| 재고관리 | 4 | 재고 Inventory, 가용재고 AvailableInventory, 재고이동 StockTransfer, 재고실사 InventoryCount |
| 창고관리 | 4 | 제품입고 ProductIncoming, 출하의뢰 ProductReleaseRequest, *출하의뢰헤더*, 제품출고 ProductRelease |
| 서비스관리 | 4 | 반품 Return, 고객제품데이터 ProductTraceParameterOnCustomer, 사후서비스신청·결과 |

*기울임* = 표준 외 보조 테이블 → `arcon:` 네임스페이스. 전체 목록과 PK·조항은 [class_catalog.csv](class_catalog.csv).

### 2.2 클래스마다 붙는 주석

`rdfs:label`(국문·영문), `skos:definition`(표준 정의), `ksx:standardClause`·`ksx:standardTable`(절·표 번호), `ksx:physicalTable`(표준 존 테이블명), `ksx:primaryKey`, `ksx:alignedTo`(IEC 62264 · OAGIS · SEMI 대응 36건, 부속서 B). 표준 본문은 전재하지 않는다(저작권, V2 §10).

### 2.3 이번에 바로잡은 것

- **회사(Enterprise)는 이제 표준 명사다.** V2 는 2024 개정안(64 명사) 기준이라 Enterprise 를 `arcon:` 확장으로 뒀지만, 2025 v1.0 은 회사·배치·라인을 추가해 67 명사가 됐다. `ksx:Enterprise` 로 옮겼다.
- **생산실적투입품목·인력·설비·품질은 생산실적의 하위 클래스가 아니다.** "생산실적의 부분"이지 "생산실적의 한 종류"가 아니므로 `rdfs:subClassOf` 를 쓰면 추론기가 투입품목 행을 생산실적으로 집계한다. `ksx:refProductionPerformance` 관계로만 잇는다.

---

## 3. 관계(객체속성) 설계

### 3.1 도출 규칙

관계목록 575 행을 다음처럼 처리했다. 결과는 [link_catalog.csv](link_catalog.csv) (231 건).

| 관계 구분 | 행 수 | 온톨로지 처리 |
|---|---|---|
| 기본 속성 (회사·사업장·공장·등록자·수정자) | 344 | 공용 객체속성 5개로 접는다: `ksx:refEnterprise` `refSite` `refPlant` `createdBy` `modifiedBy` |
| 명사 참조 | 206 | 참조 대표 컬럼명에서 `ref{어간}` 생성. ItemID → `ksx:refItem`, ParentLotID → `ksx:refParentLot` |
| 자기 참조 | 10 | 동일 규칙. 계보성 자기 참조는 전이 속성 하위로 (`refParentLot ⊑ arcon:derivedFrom`) |
| 헤더 참조 · 헤더-라인 | 4 · 3 | 문서 전체 참조는 `refRouting`·`refBOM`(→ Header), 행 단위는 `refRoutingLine`·`refBOMLine`, 라인→헤더는 `arcon:hasHeader` |
| 다형 참조 | 4 | 이동 출발지·목적지 → `arcon:Location` (공정·설비·저장소·캐리어). 유형 코드로 판별, 물리 FK 없음 |
| 표준 외 대상 | 3 | 제조번호 단위 고객 설치 제품 → `arcon:CustomerInstalledProduct` 확장 클래스 |
| 하위 목록 참조 | 1 | 창고섹션 → `ksx:refWarehouseSection` (섹션 테이블 분리 전까지 관계 검증 생략) |

이름 보정 4건: SalesDocumentNumber → `refSalesOrder`, PurchaseDocumentNumber → `refPurchaseOrder`, RequestNumber → `refAfterSalesServiceRequest`, ParentCommonCodeGroup → `refParentCommonCode`.

### 3.2 domain 을 걸지 않는 이유

`ksx:refItem` 은 37개 명사가 쓴다. `rdfs:domain` 을 걸면 OWL 의미상 "refItem 을 가진 것은 모두 그 domain 의 인스턴스"가 되어, 여러 domain 을 나열하는 순간 모든 사용처가 그 교집합 타입으로 추론된다. 그래서 **속성은 전역 1개, 사용처는 `ksx:usedIn` 주석과 SHACL `sh:property`** 로 표현한다. `rdfs:range` 는 문서화를 위해 남기되, 데이터 검증은 range 추론 없이 닫힌 세계로 돌린다(§6).

### 3.3 추론에 쓰는 핵심 공리

```turtle
arcon:derivedFrom a owl:TransitiveProperty .          # 로트 계보 전수 역추적
ksx:refParentLot rdfs:subPropertyOf arcon:derivedFrom .
arcon:componentOf a owl:TransitiveProperty .          # 다단 BOM 전개
ksx:refChildItem rdfs:subPropertyOf arcon:componentOf .
arcon:affectedSalesOrder owl:propertyChainAxiom ( ksx:refLot ksx:refProductionOrder ksx:refSalesOrder ) .
ksx:operationStartTime rdfs:subPropertyOf arcon:eventTime .   # 명사 무관 타임라인 질의
```

`affectedSalesOrder` 체인은 생성된 관계로 실제 이어지는지 확인했다: 생산품질실적 →refLot→ 로트 →refProductionOrder→ 생산지시 →refSalesOrder→ 수주오더.

---

## 4. 속성 설계

| 표준 데이터 타입 | 온톨로지 | 수 | 비고 |
|---|---|---|---|
| ID (자기 식별자) | `owl:DatatypeProperty` / xsd:string | 51 컬럼 | IRI 템플릿 재료 |
| IDREF (참조) | `owl:ObjectProperty` | 572 컬럼 → 68 속성 | §3 |
| enum | `owl:ObjectProperty` → `skos:Concept` | 141 컬럼 → 90 속성 | `ksx:codeScheme` 에 공통코드그룹 기록 |
| string · int · float · date · dateTime · boolean · duration | `owl:DatatypeProperty` (xsd 매핑) | 668 컬럼 → 321 속성 | 같은 이름은 전역 1개로 합침 |

- 코드: 공통코드그룹 77 + 단위 = `skos:ConceptScheme`, 코드 = `skos:Concept`, 2025 개정의 상위코드(ParentCommonCodeGroup/ID) = `skos:broader`. 단위는 UN/CEFACT Rec 20 코드를 함께 기록해 QUDT 매핑 근거로 쓴다.
- duration 10건(준비·가동·이동시간, 수집주기 등)은 `xsd:duration` 으로 뒀다. 표준 검토사항 1번(ISO 8601 기간 vs 숫자+단위코드 혼재)은 아직 미결이다.

---

## 5. 데이터레이크 메타 온톨로지 (lake:)

"온톨로지 기반 데이터레이크"의 핵심은 **레이크의 모든 데이터셋이 온톨로지 클래스를 가리키는 것**이다. 카탈로그 검색, 품질 규칙, 접근 권한, 계보가 모두 이 한 링크(`lake:represents`)를 타고 상속된다.

| 개념 | 정의 | 재사용 표준 |
|---|---|---|
| 존 | `lake:RawZone` → `StandardZone`(KS X 9101 테이블) → `SemanticZone`(KG) → `CuratedZone`(KPI·피처·서빙) | — |
| 데이터셋 · 필드 | `lake:Dataset ⊑ dcat:Dataset`, `lake:represents owl:Class`, `lake:Field lake:mapsToProperty` | DCAT 3 |
| 계보 | `lake:JobRun ⊑ prov:Activity`, `lake:Mapping ⊑ prov:Plan`, 문서 근거 = `lake:SourceDocument` + 페이지·섹션 | PROV-O |
| 근거 등급 | `lake:STANDARD` · `ASSERTED` · `INFERRED` · `GENERATED` (E2E 보고서 권고) | — |
| 동일성 | `lake:sameAsWithinGroup` · `lake:notSameAs` — 전역 owl:sameAs 금지 (CKD 교훈) | — |
| 품질 | `lake:QualityRule ⊑ dqv:Metric` + `lake:shape → sh:NodeShape`, 차원 = 완전성·유일성·유효성·일관성·정확성 | DQV · SHACL |
| 접근 | `lake:AccessPolicy ⊑ odrl:Policy`, 범위 = 회사·사업장·공장 × 역할 | ODRL |
| AI 자산 | `lake:EmbeddingIndex`, `lake:FeatureSet`, `lake:Model`, `lake:Prediction`(tier=GENERATED 로 KG 재적재) | — |

입찰 공고 공통 요구(raw/refined/curated 존, 출처·수집시각·스키마버전·레코드수·품질상태 메타데이터, 문서·페이지·섹션 근거, 12개월 감사로그, 신청·승인)가 위 개념에 1:1로 대응한다. 2단계 DDL 의 `catalog`·`gov` 스키마가 이를 테이블로 옮긴다.

---

## 6. IRI · Named Graph

| 대상 | 템플릿 | 예 |
|---|---|---|
| T-Box 코어 | `https://ontology.impix.co.kr/ksx9101/{Noun}` | `ksx:Lot` |
| T-Box 확장 | `https://ontology.impix.co.kr/arcon/{Term}` | `arcon:OTDRiskEvent` |
| A-Box | `https://data.impix.co.kr/arcon/{EnterpriseID}/{Noun}/{PK…}` | `…/ACME/Lot/LOT-2026-0731` |
| 코드 | `https://data.impix.co.kr/arcon/codelist/{Group}/{Code}` | `…/codelist/LotState/Start` |
| Named Graph | `…/graph/{Ent}/{Site}/{Plant}` (원장) · `…/graph/inferred/{Ent}/{Site}` (추론) | 사업장 격리 |

**V2 와 다른 점:** V2 는 A-Box IRI 에 `{Ent}/{Site}/{Plant}` 를 넣었다. 그런데 테이블정의서의 PK 는 `EnterpriseID + 명사 ID` 이고 SiteID·PlantID 는 PK 가 아니다. 로트가 공장 간 이관되면 IRI 가 바뀌어 계보가 끊긴다. 그래서 IRI 는 PK 만으로 만들고, 사업장 격리는 Named Graph 와 접근 정책으로 한다. (확정 필요 — §8)

---

## 7. 검증 결과

`tools/validate_sample.py` 로 예시 A-Box(`sample_abox.ttl`: 회사·사업장·공장·품목·설비·로트 3·설비파라미터이력)를 SHACL 검증했다. 의도적으로 넣은 위반 2건이 정확히 잡혔다.

```
conforms: False
 - Lot/LOT-2026-0799 | refSite | [KSX9101/구조] SiteID 는 필수(7.3)
 - Lot/LOT-2026-0799 | refItem | [KSX9101/관계] EnterpriseID,ItemID → ksx:ItemMaster   ← 설비를 품목으로 참조
```

검증 중 발견한 것: RDFS 추론을 켜고 검증하면 `refItem` 의 range(ItemMaster) 때문에 **잘못 참조된 설비가 품목으로 추론되어 관계 위반이 사라진다.** 적합성 검증은 range 추론을 끄고(클래스 계층만 합쳐서) 돌려야 한다. 2단계 품질 파이프라인에 그대로 반영한다.

---

## 8. 결정이 필요한 것

| # | 항목 | 이번 초안의 선택 | 대안 |
|---|---|---|---|
| D1 | A-Box IRI 에 사업장·공장 포함 | 넣지 않음 (PK 기반, §6) | V2 방식 유지 |
| D2 | duration 표현 | xsd:duration / INTERVAL | 숫자 + 단위코드 |
| D3 | 코드 참조 강제 위치 | SHACL (`sh:class skos:Concept`) + DB 는 코드 테이블 FK 미적용 | DB FK 로도 강제 |
| D4 | Property Graph 엔진 | 2단계 DDL 은 PostgreSQL 단일 (AGE 확장 여지만 둠) | Neo4j 격리 / Kùzu |
| D5 | SWRL 저작 | 초안 범위 밖. 규칙은 SHACL-AF / SPARQL CONSTRUCT 로 표현 | V2 R12 대로 SWRL → RL 컴파일 |

---

## 9. 파일

| 파일 | 설명 |
|---|---|
| `ksx9101_core.ttl` | 표준 코어 T-Box (생성) |
| `ksx9101_shapes.ttl` | 적합성 셰이프 70 (생성) |
| `ksx9101_codelists.ttl` | SKOS 코드리스트·단위 (생성) |
| `arcon_ext.ttl` | 동사·액션·리스크·KPI·유지보수·인과 확장 |
| `lake_meta.ttl` | 데이터레이크 메타 온톨로지 |
| `sample_abox.ttl` | 검증용 예시 인스턴스 |
| `class_catalog.csv` · `link_catalog.csv` | 클래스 70 · 관계 231 목록 |
| `ontology_model.json` | 목업·DDL 시드용 요약 |
| `ontology_diagram.svg` | 핵심 클래스·관계 다이어그램 |
| `../tools/gen_ontology.py` · `validate_sample.py` · `draw_diagram.py` | 생성·검증·도식 스크립트 |
