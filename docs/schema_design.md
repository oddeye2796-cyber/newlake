# 2단계 · 데이터레이크 스키마 설계 — 온톨로지를 따라가는 4개 존 + 3개 관리 스키마

작성 2026-10-14 · 버전 0.5 (Fable 리뷰 31건 + 재검토 10건 반영, §8·§9·§10) · 대상 DB: **온프레미스 PostgreSQL 16** + pgvector + TimescaleDB
검증: 로컬 PostgreSQL 16.15 + pgvector 0.6.0 에 전 파일 무오류 적용, 뷰·FK·RLS·벡터 검색 확인 (§6). TimescaleDB 경로는 문법만 확인(§6).

---

## 1. 구조 한눈에

```
             ┌──────────────────────── onto (온톨로지 레지스트리) ────────────────────────┐
             │ class 117 · property 534 · link 231 · action 5 · ontology_version          │
             └──────────────▲───────────────────────────────▲─────────────────────────────┘
                            │ represents_class_iri          │ maps_to_property_iri
┌──────────── catalog (카탈로그·계보·품질) ────────────────────────────────────────────────┐
│ dataset · dataset_field · mapping · mapping_review(HITL) · pipeline · job_run           │
│ lineage_edge · source_document · document_chunk · quality_rule/run/violation           │
└──────▲────────────────▲──────────────────▲──────────────────────▲──────────────────────┘
       │                │                  │                      │
  ┌────┴────┐     ┌─────┴──────┐     ┌─────┴──────┐        ┌──────┴──────┐
  │  raw    │ ──▶ │   ksx      │ ──▶ │   sem      │ ──▶    │   mart      │
  │ 원천 존  │ 표준화│ 표준 존     │ RML/ │ 시맨틱 존   │ 집계·  │ 활용 존      │
  │ JSONB·  │ 매핑 │ KS X 9101  │ 추론 │ 쿼드·추론·  │ 서빙   │ KPI·계보·    │
  │ 파일·시계열│    │ 70 테이블   │     │ 동일성·임베딩│       │ 리스크 후보  │
  └─────────┘     └─────▲──────┘     └────────────┘        └─────────────┘
                        │ Ontop 가상화(무복제 SPARQL)
             ┌──────────┴───────────── gov (거버넌스) ─────────────────────────────────────┐
             │ role · role_assignment(회사·사업장·공장) · access_policy · access_request    │
             │ api_token · audit_log(월 파티션, 12개월+) · action_policy · action_execution │
             └────────────────────────────────────────────────────────────────────────────┘
```

**왜 이렇게 나눴나.** 아크온 V2 의 "가상화 우선, 물질화 선택" 원칙을 레이크에 그대로 옮겼다. 기준정보·트랜잭션은 표준 존(`ksx`) 테이블이 원장이고 Ontop 이 SPARQL 로 직접 읽는다. 시맨틱 존(`sem`)에는 추론 결과, BOD 원장, 문서 유래 사실, 예측처럼 **원장에 없는 사실만** 물질화한다. 그래서 표준 존과 시맨틱 존 사이에 같은 데이터가 두 벌 생기지 않는다.

---

## 2. 파일과 적용 순서

| 순서 | 파일 | 스키마 | 내용 | 작성 |
|---|---|---|---|---|
| 1 | `00_schemas.sql` | 전체 | 스키마 7개 생성 + 확장(pgvector, TimescaleDB) + 타임존 고정 + 마이그레이션 기록표 + 파티션 유지 함수 | 수기 |
| 2 | `10_ksx_tables.sql` | ksx | KS X 9101 70 테이블 + 레이크 기술 컬럼 5개 + 국문 주석 | **생성** |
| 3 | `11_ksx_fk.sql` | ksx | FK 427개 (DEFERRABLE, 등록자·수정자 제외) + FK 인덱스 223개 | **생성** |
| 4 | `20_onto.sql` | onto | 네임스페이스·버전·클래스·속성·관계·액션 | 수기 |
| 5 | `21_catalog.sql` | catalog | 존·원천·데이터셋·필드·매핑·계보·문서·품질 | 수기 |
| 6 | `30_raw.sql` | raw | 적재 배치·원천 레코드(JSONB)·파일·시계열 원본 | 수기 |
| 6-1 | `31_raw_timescale.sql` | raw | 시계열 하이퍼테이블·압축·보존·1분 연속 집계 (TimescaleDB 있을 때만) | 수기 |
| 7 | `40_sem.sql` | sem | Named Graph·쿼드·파생 근거·동일성·별칭·임베딩·리스크 이벤트 | 수기 |
| 8 | `50_mart.sql` | mart | 계보·양품율·PPM·시간가동율·OTD·규격이탈 로트·납기리스크·WIP 뷰 8개 | 수기 |
| 9 | `60_gov.sql` | gov | 역할 9종·범위·정책·신청승인·토큰·감사로그·액션 정책/실행 | 수기 |
| 10 | `70_rls.sql` | ksx·sem·catalog·mart | 행 단위 보안 기본 적용 · DB 역할 4종(lake_agent 포함) · 시퀀스·기본 권한 · LLM SQL 실행기 | 수기 |
| 11 | `90_seed_ontology.sql` | onto·catalog | 클래스 117(표준 70 + 상위 분류·arcon 확장·lake 메타)·속성 534·관계 231·데이터셋 70·필드 1,782(기술 컬럼 350 포함). upsert | **생성** |
| 11-1 | `91_seed_actions.sql` | onto·gov | 액션 정의 5·액션 정책 2 (클래스 FK 때문에 레지스트리 다음) | 수기 |
| 12 | `95_sample_data.sql` | 전체 | 고객 클레임 시나리오 예시 데이터 | 수기 |

생성 파일은 `tools/gen_schema.py` 가 테이블정의서 추출본과 1단계 온톨로지에서 만든다. 표준이 개정되면 `gen_ontology.py` → `gen_schema.py` 를 다시 돌리면 TTL·SHACL·DDL·시드가 같이 바뀐다.

`bash tools/apply_local.sh` 로 적용한다. 파일마다 한 트랜잭션이고 `gov.schema_migration` 에 sha256 과 함께 기록되어, 다시 돌리면 적용된 파일은 건너뛴다(바뀐 파일은 경고). 이후 변경은 `V0002__*.sql` 처럼 새 파일로 넣으면 이름순으로 적용된다. TimescaleDB 가 없으면 중단하며(개발용만 `ALLOW_TS_FALLBACK=1`), 끝에 RLS 누락 검사(`gov.rls_gaps()` 0행)와 역할별 스모크 테스트를 돌린다.

---

## 3. 존별 설계 요점

### 3.1 원천 존 (raw)
- 원천 포맷 보존, append-only. `ingest_batch` 가 모든 적재의 단위이고 BOD 로 들어오면 `bod_id`·`scenario_id`(부속서 A)를 남긴다.
- `landing_record` 는 JSONB + CDC 연산(I/U/D/S), `landing_file` 은 오브젝트 스토리지 포인터 + sha256, `ts_point` 는 설비 시계열 원본. 보존 기본 6개월(`catalog.zone`).
- `ts_point` 는 TimescaleDB 하이퍼테이블이다: 12시간 청크, 2일 지나면 압축(회사·설비별 세그먼트, 파라미터·시각 순), 6개월 뒤 자동 삭제, 1분 연속 집계 `raw.ts_point_1m`(2년 보존). 확장이 없는 서버에서는 일 파티션 + 같은 이름의 일반 뷰로 대체되어 하류 쿼리는 바뀌지 않는다.
- 시계열은 전부 트리플로 만들지 않는다. 규격 이탈·상태 전이 구간만 표준 존 `trace_parameter` 로 승격한다(V2 §3.4).

### 3.2 표준 존 (ksx) — 온톨로지의 물리 원장
- 테이블정의서 DDL 그대로 70 테이블. PK = EnterpriseID + 명사 식별자. `return` 은 예약어라 `ksx."return"`.
- **레이크 기술 컬럼 5개**를 모든 테이블 끝에 붙였다: `lake_batch_id`(어느 적재에서 왔나), `lake_source_system`, `lake_loaded_at`, `lake_record_hash`(변경 감지), `lake_shacl_status`(PENDING·CONFORMS·VIOLATION). 표준 컬럼은 건드리지 않는다.
- **FK 427개, 전부 `DEFERRABLE INITIALLY DEFERRED`.** 원천마다 적재 순서가 뒤섞여도 한 트랜잭션 안에서는 순서를 따지지 않고 커밋 때만 검사한다. 예시 데이터는 일부러 자식(로트)부터 넣어 이를 확인했다. 대신 검사가 커밋에 몰리므로 적재 트랜잭션은 50만 행 이하로 자르고, 초기 적재·백필은 `gov.fk_bulk_begin/end` 로 FK 를 잠시 풀었다가 다시 검증한다(§9).
- 등록자·수정자(`creator_id`·`modifier_id` → 사원) 140개 관계는 FK 로 만들지 않는다. 원천 시스템의 등록자가 MES 사원 마스터에 없는 경우가 흔해 배치가 통째로 실패하기 때문이다. SHACL 경고로만 본다.
- 대형 이벤트 테이블 4개(`trace_parameter`·`alarm`·`operation_start`·`operation_end`)는 이벤트 시각 월 파티션이다. 보존은 DELETE 대신 파티션 DETACH/DROP.
- **시각 규약:** 표준 컬럼 `*_date_time` 은 표준 DDL 대로 `TIMESTAMP`(타임존 없음)이고 **한국 표준시 벽시계**로 저장한다. DB 와 레이크 역할의 세션 타임존을 `Asia/Seoul` 로 고정했고, 원천 시계열(`TIMESTAMPTZ`)을 승격할 때는 `ts AT TIME ZONE 'Asia/Seoul'` 로 명시 변환한다.
- FK 로 옮기지 않은 8건(다형 참조 4·표준 외 대상 3·창고섹션 1)은 `11_ksx_fk.sql` 끝에 목록으로 남겼고 SHACL·애플리케이션에서 검증한다.
- 코드 컬럼(enum 141개)은 DB FK 를 걸지 않았다. `common_code_master` PK 가 `(회사, 코드그룹, 코드)` 인데 업무 테이블에는 코드그룹 컬럼이 없어 FK 를 걸려면 생성 컬럼이 141개 필요하다. 코드 유효성은 SHACL(`sh:class skos:Concept`)과 품질 규칙으로 본다(1단계 D3).

### 3.3 시맨틱 존 (sem)
- `quad`: 물질화 사실만. 모든 행에 **근거 등급(tier)** 필수, 문서 유래면 `source_chunk_id` 로 문서·페이지·섹션까지 추적, 덮어쓰지 않고 `valid_to` 로 기간을 닫는다.
- `derivation`: 추론 사실마다 규칙(`derived_by`)과 근거 사실(`from_facts`) 기록 — "AI 가 왜 그렇게 답했나"에 답하는 근거.
- `identity_decision`: SAME 은 검증 그룹 안에서만, NOT_SAME 도 영속화해 재병합을 막는다(CKD 교훈).
- `risk_event`: 추론이 만든 납기·규격이탈·공급 리스크. Decision Engine 의 입력.

### 3.4 활용 존 (mart)
1단계 KPI 매트릭스에서 "표준 명사만으로 닫힌다"고 한 KPI 를 뷰로 만들었다.

| 뷰 | 근거 테이블 | 대응 온톨로지 |
|---|---|---|
| `v_lot_genealogy` | lot (재귀, 순환 방지) | `arcon:derivedFrom` 전이 폐포 |
| `v_kpi_yield_daily` · `v_kpi_process_ppm` | production_performance(+_quality) | `arcon:Yield` · `arcon:ProcessPPM` |
| `v_kpi_equipment_time_util` | production_performance_equipment | `arcon:OEE` 의 시간가동율 항 |
| `v_kpi_otd` | sales_order × product_release (문서번호+순번) | `arcon:OTD` |
| `v_spec_out_lot` | trace_parameter × equipment_parameter × 착공·완공 구간 | `arcon:SpecOutEvent` |
| `v_otd_risk_candidate` | 품질실적 → 생산지시 → 수주 | `arcon:OTDRiskEvent` (`affectedSalesOrder` 체인의 SQL 판) |
| `v_kpi_wip` | lot | `arcon:WIP` |

가정 하나: `produced_quantity` 는 불량 포함 총수량으로 봤다. 표준 정의 확인이 필요하다.

---

## 4. 관리 스키마

- **onto** — TTL 이 원본, 테이블은 SQL 조인용 사본. 버전 단위로 쌓고 런타임에 고치지 않는다(Setup → Execution 단방향).
- **catalog** — 핵심은 `dataset.represents_class_iri`. "로트를 담은 데이터셋 전부"(원천 MES 이력, 표준 존 테이블, KG 그래프)가 한 질의로 나오고, 클래스에 건 품질 규칙·접근 정책이 그 데이터셋 전부에 적용된다. `dataset_field.maps_to_property_iri` 는 표준 존 1,432 컬럼 전부 채워졌다(미매핑 0).
- **gov** — 범위 키를 KS X 9101 기본 속성(회사·사업장·공장)과 같게 둬서 RLS·OPA·Named Graph 가 같은 키로 격리한다. 감사로그는 월 파티션(공공 기준 12개월+). 액션은 정의(`onto.action`)와 정책(`gov.action_policy`: 언제·누가 승인·중복 억제 4시간)과 실행 원장(`gov.action_execution`: BODID·근거)으로 3분할했다.

입찰 공고 공통 요구와의 대응:

| 요구 | 반영 위치 |
|---|---|
| raw / refined / curated 존, 보존정책 | `catalog.zone` (RAW·STANDARD·SEMANTIC·CURATED, 6개월/2년) |
| 출처·수집시각·스키마버전·크기·레코드수·품질상태 메타 | `catalog.dataset` |
| 문서·페이지·섹션 근거 (위성 RFP) | `catalog.document_chunk` → `sem.quad.source_chunk_id` |
| 품질 규칙(완전성·유일성·유효성·일관성·정확성)·이력 | `catalog.quality_rule/run/violation` |
| 데이터·Key 신청 → 승인, 토큰 (코호트 RFP) | `gov.access_request` · `gov.api_token` |
| 감사로그 12개월 이상 | `gov.audit_log` 월 파티션 |
| 가명처리 여부 | `catalog.dataset.pseudonymized` · `sensitivity='PERSONAL'` |
| HITL 매핑 검토 | `catalog.mapping_review` |

---

## 5. 아직 정하지 않은 것

| # | 항목 | 초안 | 대안 |
|---|---|---|---|
2026-10-14 온프레미스 PostgreSQL 로 확정하면서 아래처럼 정했다.

| # | 항목 | 결정 | 다시 볼 시점 |
|---|---|---|---|
| S1 | 오브젝트 스토리지 테이블 포맷 | Parquet 포인터 유지 (MinIO 등 사내 스토리지) | Trino·Spark 등 여러 엔진이 같은 데이터를 읽게 되면 Iceberg |
| S2 | 시계열 저장소 | **TimescaleDB 하이퍼테이블** (`31_raw_timescale.sql`) | 설비 수천 대 이상이면 시계열 전용 인스턴스 분리 |
| S3 | 벡터 | **pgvector** `vector(1024)` + HNSW 코사인 | 수천만 건 이상이면 외부 벡터DB |
| S4 | Property Graph | 미포함 (계보는 재귀 SQL, 의미 질의는 Ontop) | 다단계 경로 탐색이 실제로 많아지면 Apache AGE |
| S5 | RLS | **기본 적용** (`70_rls.sql`) | — |

---

## 6. 검증 결과 (로컬 PostgreSQL 16.15)

- 12개 파일 순서대로 `ON_ERROR_STOP` 로 적용 → 오류 0 (TimescaleDB 미설치 상태라 31 은 건너뜀, 시계열은 대체 경로). 테이블 ksx 70 · catalog 14 · gov 12 · sem 8 · onto 6 · raw 9(파티션 포함), 뷰 8, FK 567. (v0.2 기준 — v0.4 결과는 §9)
- 예시 데이터(자식 먼저 삽입) 커밋 성공 → FK 지연 검사 동작 확인. 없는 품목을 참조하는 로트 삽입은 `fk_lot_08` 위반으로 거부.
- 뷰 결과 (예시 시나리오):
  - `v_spec_out_lot`: EQ-07 존3 온도 262.4℃·259.8℃ (USL 255) → 그 시각 진행 로트 **LOT-2026-0731**
  - `v_kpi_process_ppm`: 리플로우 공정 SOLDER 불량 34개, **34,694 PPM**
  - `v_otd_risk_candidate`: LOT-2026-0731 불량률 **3.40%** → 수주 SO-5001 (5일 후 납기) **HIGH**
  - `v_lot_genealogy`: 0731·0732 → 모로트 0730
  - `v_kpi_otd`: SO-4990 납기 내 출고(TRUE), SO-5001 미출고
- RLS (`lake_app` 역할): 범위 미설정 0건, `app.enterprise_id='ACME'` 품목 2건, 공장을 P2 로 좁히면 로트 0건. mart 뷰도 `security_invoker` 라 같은 범위가 적용됨(ACME 는 납기 리스크 1건, P2 는 0건). `lake_app` 은 원천 존 접근 거부, `lake_loader` 는 RLS 우회로 로트 4건 전부.
- pgvector: 1024차원 200건 적재 후 HNSW 인덱스로 최근접 검색 → 자기 자신이 거리 0 으로 1위.
- 시계열 대체 경로: `raw.ts_point` 2건 → `raw.ts_point_1m` 최대 262.4.
- **TimescaleDB 경로(`31_raw_timescale.sql`)는 실행 검증을 못 했다.** 이 작업 환경에서 Timescale 패키지 저장소와 GitHub 접근이 막혀 설치할 수 없었다. SQL 파서로 8개 문장 문법만 확인했다. 실제 서버에서는 `shared_preload_libraries='timescaledb'` 설정 후 `apply_local.sh` 를 돌리면 자동으로 이 파일이 적용된다.

## 7. 운영 적용 메모 (온프레미스)

- 확장: `postgresql-16-pgvector`, `timescaledb-2-postgresql-16` 패키지 설치 → `shared_preload_libraries = 'timescaledb'` → 재시작.
- 역할: `lake_loader`(적재, RLS 우회) · `lake_app`(콘솔·API, RLS 적용) · `lake_ml`(lake_app + 원천 존 읽기). NOLOGIN 으로 만들어지므로 실제 접속 계정을 만들어 이 역할을 부여한다.
- 앱은 트랜잭션마다 `SET LOCAL app.enterprise_id / app.site_ids / app.plant_ids` 를 넣는다. 커넥션 풀(pgbouncer 트랜잭션 모드)에서도 범위가 다음 요청으로 새지 않는다.
- 운영 DB 에는 `95_sample_data.sql` 을 빼고 적용한다.


## 8. Fable 리뷰 반영 (v0.3, 2026-10-14)

전체 리뷰는 `review_fable.md` (31건: 심각 2 · 높음 7 · 중간 14 · 낮음 8). 심각·높음 9건을 고쳤고 각각 로컬 PG16 에서 재현 시나리오로 다시 확인했다.

| # | 내용 | 수정 | 재검증 |
|---|---|---|---|
| F1 | 시퀀스 권한 누락으로 감사로그·쿼드 INSERT 실패 | 시퀀스 USAGE + `ALTER DEFAULT PRIVILEGES` | apply 스모크 테스트 통과 |
| F2 | sem·catalog 회사 간 노출 | `source_document`·`document_chunk`·`embedding_item` 에 범위 키, `named_graph`·`source_system` 포함 정책, `quad`·`derivation` 은 부모 경유 정책. 공용(enterprise_id NULL) 그래프·임베딩은 모두에게 | ACME 범위에서 GLOBEX 쿼드·청크·임베딩·원천시스템 0건 |
| F3 | 빈 범위 값이 회사 전체로 열림 | `'*'` 만 전체, 미설정·빈 값 거부, 공백 무시 | 빈 값 0건, `'P9, P1'` 4건 |
| F4 | 앱 계정이 범위를 스스로 바꿈 (LLM SQL 경로) | `lake_agent` 역할 + `gov.run_agent_query` (읽기 전용 트랜잭션, 서브쿼리로 단일 SELECT 강제), `set_config` 실행 권한을 신뢰 역할에만 | lake_agent 의 `set_config`·다중문·`reset role` 주입 전부 거부, 카탈로그·임베딩 접근 거부 |
| F5 | 규격 이탈 뷰가 공정 종료 후 이벤트 누락·미종료 착공 영구 매칭 | 이벤트 이전 최근 착공 1건만 LATERAL 로 선택, 종료 후면 로트 NULL. 인덱스 추가 | 12:00 이벤트 표시(로트 없음), 0801 오매칭 없음, 이벤트당 1행 |
| F6 | 불량 PPM 분모 과소 | 분모(전체 생산량)를 따로 집계 후 LEFT JOIN | 무결점 실적 추가 시 34,694 → 17,172 |
| F7 | 뷰 재생성 시 security_invoker 소실 | 8개 뷰 정의에 `WITH (security_invoker = true)` 직접 기재, 70 은 경고+안전망 | 8/8 |
| F8 | 파티션 고정 2개월 + DEFAULT | `gov.ensure_partitions()` 로 지난달~3개월 뒤 자동 생성(ts 대체 경로는 일 단위), `gov.default_partition_rows()` 알람용 | 월 5개·일 32개 생성, default 0행 |
| F9 | TimescaleDB 없을 때 조용히 저하 | apply 스크립트가 기본 중단, 대체 경로는 명시적 옵션 | 확장 없으면 종료 코드 1 |

운영 메모 추가:
- `gov.ensure_partitions` 는 매일 cron 으로: `SELECT gov.ensure_partitions('raw.landing_record','month',3); SELECT gov.ensure_partitions('gov.audit_log','month',3);`
- 범위는 항상 세 개 다 넣는다. 회사 안 전체는 `'*'`.
- LLM 이 만든 SQL 은 `BEGIN READ ONLY; SET LOCAL app.*; SET LOCAL ROLE lake_agent; SELECT gov.run_agent_query($1); COMMIT;` 로만 실행한다.
- `pg_catalog.set_config` 의 PUBLIC 실행 권한을 회수했다. 이 함수를 쓰는 외부 도구가 있으면 해당 역할에 따로 부여한다.
- 새 테이블에 범위 키를 넣으면 `SELECT gov.apply_scope_policies();` 를 다시 돌린다.

나머지 중간·낮음 22건은 v0.4 에서 반영했다(§9).

---

## 9. Fable 리뷰 나머지 반영 (v0.4, 2026-10-14)

중간 14건·낮음 8건. 빈 DB 에 처음부터 다시 적용(무오류, RLS 누락 0, 재실행 시 전 파일 건너뜀)한 뒤 지적마다 재현 시나리오로 확인했다.

| # | 내용 | 수정 | 재검증 |
|---|---|---|---|
| F10 | TIMESTAMP·TIMESTAMPTZ 혼용으로 9시간 어긋남 | DB·레이크 역할 4개 타임존 `Asia/Seoul` 고정, KST 벽시계 규약·승격 시 명시 변환을 설계서·00 에 기록 | 세션 타임존 Asia/Seoul, `'10:15'::timestamp = '10:15+09'` 참 |
| F11 | 지연 FK 대량 적재 비용 | 적재 지침(≤50만 행, IMMEDIATE), `gov.fk_bulk_begin/end`(FK 보관·해제 → NOT VALID 재생성 → VALIDATE, 파티션 테이블은 즉시 검증), 적재 역할 work_mem 256MB | ksx.lot FK 11개 해제·복구·검증, 파티션 테이블 5개 복구 |
| F12 | 등록자·수정자 FK, 저가치 인덱스 | 생성기에서 등록자·수정자 FK 140개 제외, 사업장·공장·등록자·수정자 단독 FK 인덱스 생략, 이벤트 테이블은 (회사, 공장, 시각) 복합 인덱스 | FK 567 → 427, ksx 인덱스 570 → 300 |
| F13 | 새 테이블 fail-open | 이벤트 트리거가 ksx 새 테이블에 RLS 를 바로 켜고 정책을 붙임(범위 키 없으면 0건), `gov.rls_gaps()` 검사를 apply 에 포함, 새 파티션도 정책 적용 | 새 테이블: 범위 키 있으면 ACME 1행만, 없으면 0행, 누락 0 |
| F14 | 감사로그 무결성 | 수정·삭제·TRUNCATE 트리거로 차단(앱·적재 경로. 소유자는 트리거를 끌 수 있음 — §10 N9), `enterprise_id`·`user_id` 를 `app.*` 설정에서 기본값으로, 회사 RLS(타사 행 위조 INSERT 거부) | UPDATE·DELETE·TRUNCATE 거부, 앱 INSERT 시 ACME·u-kim 자동 기록 |
| F15 | 앱이 승인 상태를 못 바꿈 | `gov.decide_action`·`gov.decide_access_request` (SECURITY DEFINER: 승인자 역할·회사·상태 전이·본인 신청 금지 확인 후 감사로그). 원장 UPDATE 권한은 회수. 두 원장에 `enterprise_id`+RLS | 역할 없음·타사·중복 처리·본인 신청 거부, 정상 승인 시 상태·승인자·감사로그 기록 |
| F16 | 레지스트리에 확장 클래스·계층·공리 없음 | 생성기가 코어+arcon_ext+lake_meta 를 모두 읽어 클래스 117(상위 88개 연결)·속성 534(전이 3, 하위 속성)·`hasHeader_*` 등록. IRI 컬럼 8곳에 FK, 액션·정책 시드는 91 로 이동 | 매달린 정책·링크 0, 오타 IRI 리스크 이벤트 거부, `refParentLot ⊑ derivedFrom` |
| F17 | IRI 단독 PK 와 버전 이력 모순 | 레지스트리는 현재 릴리스만(upsert), 과거 버전은 `artifact_uri` TTL 번들 — 설계 결정으로 명시 | 시드 재적용 가능 |
| F18 | 카탈로그 회사 범위·기술 컬럼 | `catalog.dataset.enterprise_id`(NULL=공용)+RLS, 필드·품질 실행·위반은 부모 경유 정책, 기술 컬럼 350개를 `lake:ingestBatch` 등으로 등록(lake_meta.ttl 에 속성 5개 추가) | ACME 범위에서 GLOBEX 데이터셋 0, 공용 71 |
| F19 | 쿼드 중복·인덱스 | 현재 사실 유일 인덱스(긴 리터럴은 md5), (그래프, 주어)·청크·작업 인덱스 | 같은 사실 재적재 거부, 9KB 리터럴 정상 |
| F20 | 벡터 필터 질의 재현율 | index_id 마다 HNSW 부분 인덱스를 트리거로 생성, 질의 규칙·빌드 메모리·pgvector 0.8 iterative scan 메모 | 부분 인덱스 2개 생성, 청크 질의 10건 모두 반환, 플래너가 부분 인덱스 선택 가능 |
| F21 | 마이그레이션·멱등성 | 파일별 단일 트랜잭션, `gov.schema_migration`(sha256), 재실행 건너뜀·변경 경고, `V0002__*.sql` 증분 경로 | 재실행 전부 건너뜀, 파일 변경 시 경고 |
| F22 | 대형 이벤트 테이블 | 4개 테이블 월 파티션(+DEFAULT, 매일 `ensure_partitions`), 자식 파티션까지 RLS | 파티션별 6개, 자식 직접 조회에서도 타사 0 |
| F23 | KPI 정의 3건 | OTD 는 누적 출고가 주문량에 닿은 날 기준(미완납·납기 전 NULL, 납기 지나면 FALSE), 리스크 불량률 분모를 로트 수량으로, WIP 에서 CLOSING·SCRAP 제외(예시 데이터도 공통코드 값으로) | 100개 부분 출고 → NULL(이전 TRUE), 리스크 3.4% 유지, 마감 로트 제외 |
| F24 | 계보 간선 중복 | `UNIQUE NULLS NOT DISTINCT` | 파이프라인 없는 같은 간선 2번째 거부 |
| F25 | 동일성 판정 정렬 | `COLLATE "C"` 비교 | 제약 정의 확인 |
| F26 | 검증 상태 CHECK | 70 테이블 `lake_shacl_status` CHECK | 'BOGUS' 거부 |
| F27 | apply 오류 삼킴 | DB 가 없을 때만 createdb, 샘플 조회는 SAMPLE=1 일 때만 | — |
| F28 | 원천 존 append-only | 적재 역할의 raw UPDATE·DELETE 회수, 배치 상태 컬럼만 UPDATE | DELETE 거부, 배치 상태 갱신 가능 |
| F29 | TimescaleDB 용량 | 12시간 청크, 2일 후 압축, 세그먼트 (회사, 설비)·정렬 (파라미터, 시각) | 실행 못 함(패키지 접근 불가) — 운영 서버에서 압축률 비교 필요 |
| F30 | 문서 sha256 유일성 | `(회사, 데이터셋, sha256)` | — |
| F31 | 매핑 기본 승인 | 기본값 PROPOSED, 시드만 APPROVED 명시 | 시드 1,782 APPROVED |

운영 메모 추가:
- 서버 코드는 범위와 함께 `SET LOCAL app.user_id = '<IdP subject>'` 도 넣는다. 감사로그·승인 함수가 이 값을 쓴다.
- 승인·반려는 `SELECT gov.decide_action(id, true|false, '메모')`, 이용 신청은 `gov.decide_access_request(...)` 로만 한다.
- 이벤트 트리거는 슈퍼유저가 만든다. 권한이 없어 못 만들면 경고가 나오고, 그때는 마이그레이션마다 `gov.apply_scope_policies()` 와 `gov.rls_gaps()` 를 직접 돌린다.
- 감사로그 보존 만료는 `ALTER TABLE gov.audit_log DETACH PARTITION gov.audit_log_YYYY_MM` 후 보관·DROP. DB 직접 접속 감사는 `pgaudit` 를 켠다.
- 테이블 소유자를 운영 계정과 분리하는 `lake_owner` NOLOGIN 역할은 운영 배포 때 만든다(지금은 postgres 소유).
- v0.3 DB 를 이미 띄웠다면 v0.4 는 기준선 파일이 바뀐 것이라 새 DB 에 다시 적용하는 게 가장 간단하다. 기존 DB 를 살려야 하면 차이를 `V0002__review_fixes.sql` 로 만들어야 한다.

---

## 10. Fable 재검토 반영 (v0.5, 2026-10-14)

v0.4 를 Fable 이 빈 DB 에 다시 올려 실제 접속 계정(`svc_app IN ROLE lake_app` 등)으로 재현했다. 원 지적 31건 중 해결 22 · 부분 해결 7 · 미해결 2, 새 발견 10건(N1–N10). 전체 보고서는 `review_fable_v04.md`. 10건 모두 고쳤고, 같은 방식(실제 접속 계정)으로 다시 확인했다.

| # | 심각도 | 내용 | 수정 | 재검증 |
|---|---|---|---|---|
| N1 | 심각 | LLM SQL 실행기에 괄호를 닫고 `; RESET ROLE; SET …` 을 이어 붙여 타사 문서 청크 열람 | `gov.run_agent_query` 를 `OPEN … FOR EXECUTE` 커서로 교체(질의 한 개만 허용). 에이전트는 lake_app 멤버가 아닌 전용 접속 계정 권장 | 주입 문자열 → 문법 오류, `SELECT 1; RESET ROLE` → "multi-query" 거부, 정상 질의·리터럴 속 `;` 는 동작 |
| N2 | 높음 | 소유자 없는 데이터셋 신청을 역할 없는 사용자가 승인 (NULL 논리) | 판정식을 `IS NOT TRUE` 로 접음 | 역할 없는 u-park 승인 거부 |
| N3 | 높음 | 정책 재적용이 매번 109개 테이블에 배타 잠금 | 이미 RLS·정책이 있는 테이블은 건너뜀(`apply_scope_policies(p_force)`), 새 파티션에만 적용 | 변경 없을 때 배타 잠금 0, 파티션 2개 생성 시 감사로그 부모·DEFAULT·새 파티션만 잠금 |
| N4 | 높음 | BYPASSRLS 가 멤버에게 상속되지 않아 적재 접속 계정이 RLS 에 막힘 | 70 머리말·운영 메모에 "접속 계정 자체에 BYPASSRLS", apply 가 BYPASSRLS 없는 lake_loader 접속 멤버를 경고 | svc_loader 생성 시 경고 출력 |
| N5 | 중간 | 범위 키 없는 보조 테이블 전사 노출 | `identity_decision`·`alias`·`pipeline`·`job_run`·`lineage_edge` 에 `enterprise_id`(NULL=공용) + 정책 | ACME 범위에서 GLOBEX 작업 실행 기록 0 |
| N6 | 중간 | cron 이 UTC 세션이면 파티션 경계가 9시간 어긋나 이후 월 생성 차단 | `ensure_partitions` 에 함수 단위 `SET timezone = 'Asia/Seoul'` | UTC 세션에서 만든 경계가 KST 자정(전날 15:00 UTC) |
| N7 | 중간 | 클라이언트가 `PGTZ=UTC` 로 붙으면 KST 규약이 깨짐 | mart 뷰의 "오늘"을 `(now() AT TIME ZONE 'Asia/Seoul')::date` 로. 커넥션 풀에 `options=-c timezone=Asia/Seoul` 강제(운영 메모) | 뷰 정의 확인. 세션 타임존 자체는 클라이언트가 바꿀 수 있어 풀 설정이 필요 |
| N8 | 중간 | 소유자가 아닌 DBA 의 CREATE TABLE 이 이벤트 트리거 실패로 롤백 | `apply_scope_policies`·`on_create_table` 를 SECURITY DEFINER(search_path 고정), PUBLIC 실행 회수 | dba_tmp 의 sem 테이블 생성 성공, RLS·정책 자동 적용 |
| N9 | 중간 | 감사로그: 소유자 트리거 해제, 파티션 직접 TRUNCATE | 기존·새 파티션마다 TRUNCATE 트리거. 소유자 우회는 트리거로 못 막으므로 설명을 고치고 lake_owner 분리·pgaudit·WORM 보관을 운영 요건으로 | 파티션 직접 TRUNCATE 거부 |
| N10 | 낮음 | 공장 한정 승인자가 다른 공장 액션 승인 | `action_execution` 에 사업장·공장, 승인자 범위가 덮을 때만 승인(회사 단위 액션은 회사 전체 범위만) | P2 한정 품질엔지니어: P1 액션 거부, P2 액션 승인 |

운영 메모 추가:
- 적재 접속 계정: `CREATE ROLE svc_loader LOGIN BYPASSRLS IN ROLE lake_loader;`
- 에이전트 접속 계정: `CREATE ROLE svc_agent LOGIN IN ROLE lake_agent;` (lake_app 멤버로 만들지 않는다). 실행은 `BEGIN READ ONLY; SET LOCAL app.*; SELECT gov.run_agent_query($1); COMMIT;`
- 커넥션 풀(pgbouncer·JDBC·Airflow)은 접속 옵션에 `-c timezone=Asia/Seoul` 를 넣는다.
- 정책 정의 자체를 바꾼 마이그레이션은 점검 시간에 `SELECT gov.apply_scope_policies(true);` 로 전부 다시 만든다.
- `lake_ml` 은 `lake_app` 멤버라 승인 함수 실행권도 물려받는다. ML 계정에 승인권이 필요 없으면 운영 배포 때 lake_ml 을 lake_app 에서 분리한다.
- 남은 검증 공백: TimescaleDB 경로(31)는 여전히 문법만 확인했다. 운영 서버에서 apply 후 압축률을 한 번 확인해야 한다.

