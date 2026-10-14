# 2단계 스키마 리뷰 — 온프레미스 PostgreSQL 16 + pgvector + TimescaleDB

리뷰 2026-10-14 · 대상 `02_schema/*.sql` v0.2, `tools/gen_schema.py`, `tools/apply_local.sh` · 검증 환경: 로컬 PG 16.15 + pgvector 0.6.0 (TimescaleDB 없음, `lake` DB 에 전체 적용된 상태를 `review_scratch` 로 복제해 실험)

**요약**
1. 판정: 구조(4 존 + onto/catalog/gov, 생성기 기반 70 테이블, catalog→onto 연결)는 타당하고 적용은 무오류이나, **현재 상태로 운영 투입하면 첫 적재·첫 감사 기록에서 실패**하고 **다중 회사 환경에서 시맨틱·카탈로그 존이 격리되지 않는다.**
2. 최우선: 시퀀스 권한 누락 — `lake_app` 의 `gov.audit_log` INSERT, `lake_loader` 의 `sem.quad`·`catalog.quality_violation` INSERT 가 `permission denied for sequence` 로 실패 (확인됨). `GRANT USAGE ON ALL SEQUENCES` + `ALTER DEFAULT PRIVILEGES` 로 해결.
3. 두 번째: RLS 가 `ksx` 70 + `sem.risk_event` 에만 걸려 `sem.quad`·`named_graph`·`embedding_item`·`catalog.document_chunk`·`source_system` 은 ACME 범위의 `lake_app` 이 GLOBEX 데이터를 그대로 읽는다 (확인됨). 범위 키 추가 + 정책, 또는 단일 회사 전제를 문서화.
4. 세 번째: `mart` 뷰 2개의 로직 오류(`v_spec_out_lot` 이 공정 종료 후 이탈 이벤트를 누락·미종료 로트를 영구 매칭, `v_kpi_process_ppm` 분모 과소) 와 `security_invoker` 가 `CREATE OR REPLACE VIEW` 한 번에 사라지는 구조 (모두 확인됨).
5. 집계: 심각 2 · 높음 7 · 중간 14 · 낮음 8 = 31건. TimescaleDB 경로(31)는 실행 검증 불가라 문법·제약 조건을 추론으로만 봤고, 하이퍼테이블 PK·압축·연속 집계 제약 자체는 충족한다.

표기: **확인됨** = SQL 실행으로 재현 · **추정** = 코드 읽기와 PG/TimescaleDB 동작 지식으로 판단.

---

## 1. 심각

### F1. 시퀀스 USAGE 권한 누락 — 감사로그·쿼드·품질위반 INSERT 가 실패한다 (확인됨)
- 위치: `70_rls.sql:1031-1038` (GRANT 블록). 영향 테이블: `gov.audit_log`(BIGSERIAL), `sem.quad`, `sem.identity_decision`, `catalog.quality_violation`, `catalog.mapping_review`, `catalog.lineage_edge`, `onto.link`.
- 문제: `GRANT ... ON ALL TABLES` 는 시퀀스를 포함하지 않는다. `pg_class.relacl` 을 보면 7개 시퀀스 모두 ACL 이 비어 있다.
- 재현:
  ```
  SET ROLE lake_app;    INSERT INTO gov.audit_log (channel, action) VALUES ('UI','read');
  → ERROR: permission denied for sequence audit_log_audit_id_seq
  SET ROLE lake_loader; INSERT INTO sem.quad (...) → permission denied for sequence quad_quad_id_seq
                        INSERT INTO catalog.quality_violation (...) → permission denied for sequence quality_violation_violation_id_seq
  ```
- 시나리오: 콘솔 첫 로그인의 감사 기록, KG 물질화 파이프라인 첫 커밋, SHACL 검증 첫 위반 저장이 전부 실패. 설계서 §6 검증은 postgres(소유자)로만 돌려 잡히지 않았다.
- 수정:
  ```sql
  GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sem, catalog TO lake_loader;
  GRANT USAGE, SELECT ON SEQUENCE gov.audit_log_audit_id_seq TO lake_app, lake_loader;
  ALTER DEFAULT PRIVILEGES IN SCHEMA sem, catalog GRANT USAGE, SELECT ON SEQUENCES TO lake_loader;
  ```
  장기적으로는 BIGSERIAL 대신 `GENERATED ALWAYS AS IDENTITY` 를 써도 시퀀스 권한은 여전히 필요하므로, 역할별 스모크 테스트(`SET ROLE` 후 INSERT)를 apply 스크립트 끝에 넣을 것.

### F2. 시맨틱·카탈로그 존 회사 간 격리 없음 (확인됨)
- 위치: `70_rls.sql:1006-1008` (대상 = `ksx.*` + `sem.risk_event` 만), `40_sem.sql` (`quad`·`named_graph`·`embedding_item`·`derivation`·`alias`), `21_catalog.sql` (`source_system`·`source_document`·`document_chunk`), `70_rls.sql:1036` (`lake_app` 에 sem·catalog 전체 SELECT).
- 재현: GLOBEX 의 `named_graph`+`quad`, `embedding_item.content`, CONFIDENTIAL `document_chunk` 를 넣고 `lake_app` 을 `app.enterprise_id='ACME'` 로 조회 → 전부 보인다.
  ```
  quad: GLOBEX secret lot | embedding_item: GLOBEX 단가 계약서 본문 | document_chunk: GLOBEX 단가 1,250원/EA | source_system: ERP-G GLOBEX
  ```
- 시나리오: 설계가 "회사·사업장·공장 키로 RLS·OPA·Named Graph 가 같은 격리"를 약속하지만 SQL 경로에서 KG 물질화 사실·RAG 청크·임베딩 원문은 격리되지 않는다. 문서 유래 사실(`source_chunk_id`)과 벡터 검색은 그 자체가 가장 민감한 데이터다.
- 수정(택1, 다중 회사면 (a)):
  (a) 범위 키를 추가하고 정책을 건다.
  ```sql
  -- quad: graph 를 통해 범위 판정
  ALTER TABLE sem.quad ENABLE ROW LEVEL SECURITY;
  CREATE POLICY p_scope ON sem.quad USING (EXISTS (
     SELECT 1 FROM sem.named_graph g WHERE g.graph_iri = quad.graph_iri
        AND gov.scope_ok(g.enterprise_id, g.site_id, g.plant_id)));
  -- named_graph / source_system / app_user: enterprise_id 그대로
  -- embedding_item, source_document, document_chunk: enterprise_id VARCHAR(50) NOT NULL 추가 후 동일 정책
  ```
  `named_graph` 의 TBOX/SHAPES/CODELIST 처럼 공용 그래프는 `enterprise_id IS NULL OR scope_ok(...)` 로 허용.
  (b) 단일 회사 배포만 지원한다면 설계서 §4 gov 항목과 `70_rls.sql` 머리말에 "sem·catalog 는 회사 격리 없음, 회사별 DB 분리" 를 명시.

---

## 2. 높음

### F3. `gov.scope_ok` 가 빈 문자열을 와일드카드로 해석한다 — fail-open (확인됨)
- 위치: `70_rls.sql:996-999` `coalesce(nullif(current_setting('app.site_ids', true), ''), '*') = '*'`.
- 재현: `app.plant_ids='P2'` → 로트 0건, `app.plant_ids=''` → 4건(회사 전체). 또 `'P9, P1'` 처럼 공백이 섞이면 0건(trim 없음).
- 시나리오: 앱이 "권한 있는 공장 목록이 비었다"를 `''` 로 직렬화하면(흔한 버그) 회사 전체가 열린다. 반대로 공백 하나로 전부 닫힌다.
- 수정:
  ```sql
  CREATE OR REPLACE FUNCTION gov.scope_ok(p_ent text, p_site text, p_plant text) RETURNS boolean
  LANGUAGE sql STABLE AS $$
    SELECT p_ent IS NOT NULL AND p_ent = current_setting('app.enterprise_id', true)
       AND (current_setting('app.site_ids', true) = '*'
            OR p_site IS NULL
            OR p_site = ANY (string_to_array(replace(current_setting('app.site_ids', true), ' ', ''), ',')))
       AND (current_setting('app.plant_ids', true) = '*'
            OR p_plant IS NULL
            OR p_plant = ANY (string_to_array(replace(current_setting('app.plant_ids', true), ' ', ''), ',')))
  $$;
  ```
  미설정·빈 문자열은 모두 거부되고 `'*'` 만 전체 허용이 된다. `p_site IS NULL` 허용은 `sem.risk_event` 처럼 범위가 NULL 인 행을 회사 전체에 보여주는 결정이므로 의도라면 주석으로 남길 것.

### F4. 범위 GUC 를 제한 대상 역할이 스스로 바꿀 수 있다 — Text-to-SQL 에이전트 경로의 권한 상승 (확인됨)
- 위치: `70_rls.sql:979-981` 설계 전제("앱이 트랜잭션마다 SET LOCAL"), `60_gov.sql:844` `agent` 역할(MCP 경유 조회).
- 재현: `SET ROLE lake_app; SELECT set_config('app.enterprise_id','GLOBEX',false);` → 성공.
- 시나리오: 사용자 GUC 는 누구나 SET 할 수 있다. LLM 에이전트가 생성한 SQL 이 `lake_app` 으로 실행되는 순간 프롬프트 인젝션 한 줄(`SET app.enterprise_id='GLOBEX'`)로 회사 경계를 넘는다. 일반 API 도 SQL 인젝션 시 동일.
- 수정: (1) 에이전트·Text-to-SQL 은 `lake_app` 직접 접속이 아니라 서버가 `BEGIN; SET LOCAL ...; SET TRANSACTION READ ONLY;` 를 심은 뒤 **단일 SELECT 문만** 허용(파서로 `SET`/`set_config`/`;` 다중문 거부). (2) 또는 범위를 세션 사용자에서 유도: `gov.role_assignment` 를 읽어 범위를 계산하는 `SECURITY DEFINER` 함수를 정책에서 쓰고 GUC 를 아예 쓰지 않는다. (3) 회사 수가 적으면 회사별 DB 역할(`lake_app_acme`)과 `enterprise_id = current_user` 매핑 테이블이 가장 단순하다.

### F5. `mart.v_spec_out_lot` 로직 오류 2건 (확인됨)
- 위치: `50_mart.sql:791-799`.
- (a) 매칭된 로트의 공정이 끝난 뒤 발생한 이탈 이벤트가 **뷰에서 사라진다.** 조인 조건은 `operation_start_time <= event` 뿐이라 종료된 로트가 매칭되고, WHERE 의 `tp.event_date_time <= oe.operation_end_time` 가 그 행을 버린다(`lot_id IS NULL` 분기는 애초에 매칭이 없을 때만 산다). 재현: EQ-07 에 12:00 이탈(270℃) 추가 → 뷰 2건 그대로, 12:00 행 없음.
- (b) 같은 설비에 **완공 기록이 없는 착공**이 하나라도 있으면 그 로트가 이후 모든 이벤트에 영구히 붙는다. 재현: LOT-2026-0801 OP-20 착공(EQ-07, 전전날)만 넣자 3개 이벤트 모두에 0801 이 추가 매칭(5행).
- (c) 착공 행마다 1행이 나와 이벤트가 중복 집계된다(승격 파이프라인이 이 뷰를 입력으로 쓰면 `risk_event` 중복).
- 수정: 이벤트 시각 이전 **가장 최근 착공 1건**만 고르고, 그 로트의 완공이 이벤트보다 앞이면 "진행 로트 없음"으로 둔다.
  ```sql
  CREATE OR REPLACE VIEW mart.v_spec_out_lot WITH (security_invoker = true) AS
  SELECT tp.enterprise_id, tp.plant_id, tp.equipment_id, tp.parameter_id, ep.parameter_name,
         tp.event_date_time, tp.parameter_value, ep.lsl, ep.usl,
         CASE WHEN oe.operation_end_time IS NULL OR tp.event_date_time <= oe.operation_end_time THEN os.lot_id END AS lot_id,
         CASE WHEN oe.operation_end_time IS NULL OR tp.event_date_time <= oe.operation_end_time THEN os.operation_id END AS operation_id,
         os.operation_start_time, oe.operation_end_time
  FROM ksx.trace_parameter tp
  JOIN ksx.equipment_parameter ep ON ep.enterprise_id = tp.enterprise_id AND ep.parameter_id = tp.parameter_id
  LEFT JOIN LATERAL (
      SELECT s.lot_id, s.operation_id, s.operation_start_time FROM ksx.operation_start s
      WHERE s.enterprise_id = tp.enterprise_id AND s.equipment_id = tp.equipment_id
        AND s.operation_start_time <= tp.event_date_time
      ORDER BY s.operation_start_time DESC LIMIT 1) os ON TRUE
  LEFT JOIN LATERAL (
      SELECT min(e.operation_end_time) AS operation_end_time FROM ksx.operation_end e
      WHERE e.enterprise_id = tp.enterprise_id AND e.lot_id = os.lot_id AND e.operation_id = os.operation_id
        AND e.operation_end_time >= os.operation_start_time) oe ON TRUE
  WHERE tp.parameter_value < ep.lsl OR tp.parameter_value > ep.usl;
  ```
  `operation_start` 에 `(enterprise_id, equipment_id, operation_start_time DESC)` 인덱스 필요(현재 FK 인덱스는 `(enterprise_id, equipment_id)` 뿐).

### F6. `mart.v_kpi_process_ppm` 분모가 불량이 있는 실적 행만 합산 — PPM 과대 (확인됨)
- 위치: `50_mart.sql:744-756`. `q`(품질실적) 를 기준으로 `production_performance` 를 INNER JOIN 하므로 불량유형 행이 없는 실적은 분모에서 빠진다.
- 재현: 같은 날 OP-40 에 1,000개 무결점 실적(PP-9002) 추가 → 뷰는 여전히 34 / 980 = 34,694 PPM. 실제 34 / 1,980 = 17,172.
- 수정: 분모를 별도 집계 후 조인.
  ```sql
  WITH d AS (SELECT enterprise_id, plant_id, production_performance_date AS perf_date, operation_id, sum(produced_quantity) AS produced_qty
             FROM ksx.production_performance WHERE coalesce(cancel_indicator, FALSE) = FALSE GROUP BY 1,2,3,4),
       n AS (SELECT p.enterprise_id, p.plant_id, p.production_performance_date AS perf_date, q.operation_id, q.defect_type_code, sum(q.defect_type_quantity) AS defect_qty
             FROM ksx.production_performance_quality q JOIN ksx.production_performance p USING (enterprise_id, production_performance_id, production_performance_sequence)
             GROUP BY 1,2,3,4,5)
  SELECT d.*, n.defect_type_code, coalesce(n.defect_qty,0) AS defect_qty, round(1e6*coalesce(n.defect_qty,0)/nullif(d.produced_qty,0)) AS ppm
  FROM d LEFT JOIN n USING (enterprise_id, plant_id, perf_date, operation_id);
  ```
  품질실적의 `operation_id` 와 실적의 `operation_id` 중 어느 쪽이 공정 기준인지도 명시할 것(현재 뷰는 `q.operation_id`).

### F7. `security_invoker` 가 사후 ALTER 로만 걸려 있어 뷰를 다시 만들면 RLS 우회로 되돌아간다 (확인됨)
- 위치: `70_rls.sql:1020-1027` (ALTER VIEW 루프) vs `50_mart.sql` (옵션 없는 `CREATE OR REPLACE VIEW`).
- 재현: `CREATE OR REPLACE VIEW mart.v_kpi_wip AS <동일 정의>` 후 `pg_class.reloptions` = NULL. 소유자(postgres) 권한으로 실행되어 `lake_app` 이 뷰 경유로 전 회사 WIP 를 본다.
- 시나리오: F5·F6 수정처럼 뷰 하나를 고쳐 배포하는 순간 조용히 열린다. 50 재적용 후 70 을 다시 돌리지 않으면 영구.
- 수정: 8개 뷰 정의에 `WITH (security_invoker = true)` 를 직접 넣고 70 의 루프는 안전망으로만 남긴다. CI 에 `SELECT relname FROM pg_class WHERE relnamespace='mart'::regnamespace AND relkind='v' AND coalesce(reloptions::text,'') NOT LIKE '%security_invoker=true%'` 가 0행인지 검사.

### F8. 파티션 운영: DEFAULT 파티션 + 월 파티션 1~2개, 자동화 없음 (확인됨)
- 위치: `30_raw.sql:520-522` (landing_record 10·11월+default), `30_raw.sql:558-559` (ts_point 대체 경로 10월+default 만), `60_gov.sql:925-927` (audit_log 10·11월+default).
- 재현: `audit_log` 에 12월 행 1건 INSERT(→ default) 후 `CREATE TABLE gov.audit_log_2026_12 PARTITION OF ...` → `ERROR: updated partition constraint for default partition "audit_log_default" would be violated by some row`.
- 시나리오: 12월 1일 0시부터 모든 행이 default 로 들어가고, 뒤늦게 월 파티션을 만들려면 default 를 DETACH → 행 이동 → 재ATTACH 를 해야 한다(감사로그는 쓰기가 멈추지 않으므로 잠금 경합). `ts_point` 대체 경로는 11월부터 전부 default 라 보존(DROP PARTITION)도 불가능.
- 수정: `pg_partman`(온프레미스 패키지 있음) 으로 `premake=3`, 또는 월초 cron 이 `date_trunc('month', now()) + 1..3 month` 파티션을 미리 만들고 `audit_log_default`·`landing_record_default` 행 수가 0 이 아니면 알람. `ts_point` 대체 경로는 **일 파티션**으로.

### F9. TimescaleDB 부재 시 조용한 성능 저하 + 승격 경로 없음 (구조 확인됨 / Timescale 동작 추정)
- 위치: `00_schemas.sql:193-202` (`EXCEPTION WHEN OTHERS` 로 경고만), `30_raw.sql:556-563` (월 파티션 + 전수 집계 뷰), `apply_local.sh:11-15` (건너뜀 메시지만), `31_raw_timescale.sql`.
- 문제: `shared_preload_libraries` 누락이나 패키지 미설치가 WARNING 한 줄로 끝나고 86M 행/일 테이블이 월 파티션(월 2.6G 행, PK 인덱스만) + 질의마다 전수 GROUP BY 하는 `ts_point_1m` 뷰로 만들어진다. 리뷰 대상 `lake` DB 가 정확히 이 상태다. 나중에 Timescale 을 올려도 `create_hypertable` 은 선언적 파티션 테이블을 받지 않고(추정), `raw.ts_point_1m` 뷰 이름이 연속 집계와 충돌해 31 이 실패한다(추정).
- 수정: `apply_local.sh` 에 `REQUIRE_TIMESCALE=1` 기본값을 두고 확장이 없으면 즉시 종료(개발용 `--allow-fallback` 만 예외). 승격 절차를 문서화: `raw.ts_point_new` 하이퍼테이블 생성 → `INSERT ... SELECT` 청크 단위 복사 → `DROP VIEW raw.ts_point_1m` → 이름 교체 → 31 적용. 31 자체의 제약(PK 에 `ts` 포함, `compress_segmentby ∪ orderby ⊇ PK`, 연속 집계가 단순 집계·`time_bucket` GROUP BY, 트랜잭션 밖 실행)은 충족한다(추정).

---

## 3. 중간

### F10. TIMESTAMP(표준 175개) 와 TIMESTAMPTZ(레이크·raw 70개) 혼용 — 세션 타임존에 따라 9시간 어긋난다 (확인됨)
- 위치: `10_ksx_tables.sql` 전체(`*_date_time TIMESTAMP`), `30_raw.sql:547` (`ts TIMESTAMPTZ`), `40_sem`·`60_gov` TIMESTAMPTZ.
- 재현: `'2026-10-12 10:15'::timestamp = '2026-10-12 10:15+09'::timestamptz` → UTC 세션 false, Asia/Seoul 세션 true.
- 시나리오: `raw.ts_point.ts` → `ksx.trace_parameter.event_date_time` 승격을 Airflow(UTC 컨테이너)가 하면 KST 벽시계가 9시간 밀려 `v_spec_out_lot` 의 착공·완공 구간 매칭이 깨진다. Ontop 의 xsd:dateTime 직렬화도 세션마다 달라진다.
- 수정: 표준 컬럼 타입은 못 바꾸므로 **DB 와 역할 수준에서 타임존을 고정**하고 변환을 명시한다: `ALTER DATABASE lake SET timezone='Asia/Seoul'; ALTER ROLE lake_loader SET timezone='Asia/Seoul';` 승격 SQL 은 `ts AT TIME ZONE 'Asia/Seoul'`. 설계서에 "ksx TIMESTAMP = KST 벽시계" 를 규약으로 기록.

### F11. 567개 DEFERRABLE INITIALLY DEFERRED FK 의 대량 적재 비용 (확인됨)
- 위치: `11_ksx_fk.sql` 전체, `gen_schema.py:96`.
- 측정(trace_parameter, FK 7개, 30만 행 1트랜잭션): 지연 검사 INSERT 4.7s + **COMMIT 7.4s** = 12.1s · `SET CONSTRAINTS ALL IMMEDIATE` 11.7s · 트리거 비활성 4.4s. FK 검사가 적재 시간의 ~64%, 지연 큐(30만×7 = 210만 이벤트)는 커밋까지 백엔드 메모리에 남고 커밋 중 잠금을 쥔다.
- 시나리오: 일 배치 1,000만 행을 한 트랜잭션에 넣으면 7천만 이벤트(수 GB) → OOM 또는 수 분 커밋 정지. 설계서는 "커밋 때만 검사" 장점만 적고 비용은 없다.
- 수정: 적재 트랜잭션을 ≤ 50~100만 행으로 자르고, 순서가 보장되는 원천은 `SET CONSTRAINTS ALL IMMEDIATE`; 백필·초기 적재는 `ALTER TABLE ... DISABLE TRIGGER ALL` 또는 FK 를 `NOT VALID` 로 두고 `VALIDATE CONSTRAINT` 를 나눠 실행(헤더 주석대로). 적재 역할 세션에 `work_mem`·`maintenance_work_mem` 상향.

### F12. 등록자·수정자 FK 140개와 저가치 FK 인덱스 277개 (확인됨)
- 위치: `11_ksx_fk.sql` (`fk_*_0[2-5]` 류), `gen_schema.py:124-134` (인덱스 생성 규칙).
- 문제: (a) 모든 테이블의 `creator_id`·`modifier_id` 가 `ksx.personnel` 을 참조하고 `site → personnel → site` 가 순환한다. ERP·HR·EAP 의 등록자 ID 는 MES 사원 마스터에 없는 경우가 흔해 배치 커밋이 실패한다. (b) `ksx` 인덱스 570개 중 277개가 `(enterprise_id, site_id|plant_id|creator_id|modifier_id)` — 선택도가 낮아 거의 쓰이지 않으면서 쓰기 증폭만 낸다(30만 행×3 적재 후 trace_parameter 힙 80MB vs 인덱스 76MB).
- 수정: `gen_schema.py` 에서 `관계 구분='기본 속성'` 중 creator/modifier 는 FK 생성 대상에서 빼고(SHACL 로 검증), 인덱스 생성 시 `site_id/plant_id/creator_id/modifier_id` 단독 FK 는 건너뛴다. 이벤트성 대형 테이블만 `(enterprise_id, plant_id, <event time>)` 복합 인덱스를 수기로.

### F13. 신규 객체 fail-open: 기본 권한 없음, RLS 활성화는 1회성 루프 (확인됨)
- 위치: `70_rls.sql:1003-1017`, `1030-1042`; `pg_default_acl` 0행.
- 시나리오: 표준 개정으로 `ksx` 테이블이 추가되거나 catalog 에 테이블을 더하면 (1) `lake_app` 에 권한이 없어 장애, (2) 누군가 `GRANT SELECT ON ALL TABLES` 를 다시 돌리면 **RLS 없는 테이블이 전 회사 노출**.
- 수정:
  ```sql
  ALTER DEFAULT PRIVILEGES IN SCHEMA ksx, sem, mart, onto, catalog GRANT SELECT ON TABLES TO lake_app;
  ALTER DEFAULT PRIVILEGES IN SCHEMA raw, ksx, sem, catalog GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lake_loader;
  ```
  70 의 RLS 루프를 `gov.apply_rls()` 함수로 빼서 마이그레이션마다 호출하고, CI 에 "ksx·sem 에 `relrowsecurity=false` 인 테이블 0개" 검사를 둔다.

### F14. 감사로그 무결성 — append-only 강제 없음 (확인됨)
- 위치: `60_gov.sql:911-928`. 사용자 트리거 0개, 소유자는 UPDATE/DELETE 가능, `lake_app` 이 임의 `user_id` 로 INSERT 가능, `enterprise_id` 없음.
- 수정: (1) `CREATE TRIGGER trg_audit_immutable BEFORE UPDATE OR DELETE ON gov.audit_log FOR EACH STATEMENT EXECUTE FUNCTION gov.raise_immutable();` (2) 테이블 소유자를 별도 `lake_owner` NOLOGIN 역할로 두고 운영 계정에서 분리. (3) `enterprise_id VARCHAR(50)` 추가(회사별 감사 추출 요구). (4) DB 수준 접근 감사는 `pgaudit` 로 보완(SQL 경로의 `channel='SQL'` 을 앱이 기록할 수 없음).

### F15. `lake_app` 이 `gov.action_execution` 상태를 바꿀 수 없다 (확인됨)
- 위치: `70_rls.sql:1038` (SELECT, INSERT 만). `UPDATE ... SET status='APPROVED'` → `permission denied for table action_execution`. `access_request` 도 동일(승인·거절 불가).
- 수정: 상태 전이를 `SECURITY DEFINER` 함수(`gov.approve_action(execution_id, approver)`)로 캡슐화해 EXECUTE 만 부여하거나, 서비스 역할 `lake_gov` 를 분리.

### F16. 온톨로지 레지스트리가 설계가 의존하는 공리·확장 클래스를 담지 못한다 (확인됨)
- 위치: `20_onto.sql:234-261`, `90_seed_ontology.sql`, `gen_schema.py:140-170`.
- 사실: `onto.class` 70개 중 arcon 은 헤더 3개뿐 → `arcon_ext.ttl` 의 17개 클래스(RiskEvent 3종, MaintenanceRequest, KPI 등) 부재. 그 결과 `gov.action_policy.trigger_class_iri` 2건, `onto.action.target_class_iri` 1건, `sem.risk_event.event_class_iri` 가 레지스트리에 없는 IRI 를 가리킨다. `onto.link` 의 속성 3건(`arcon:hasHeader_*`)도 `onto.property` 에 없다. `parent_class_iri` 0/70, `is_transitive` 0/480, `super_property_iri` 0 — 1단계 §3.3 의 `derivedFrom` 전이·`refParentLot ⊑ derivedFrom` 이 SQL 쪽에 없다.
- 시나리오: 카탈로그 UI 의 "클래스 트리", 접근 정책의 클래스 단위 상속, 액션 정책 유효성 검사가 모두 빈 결과를 낸다. IRI 컬럼에 FK 가 없어 오타도 잡히지 않는다.
- 수정: `gen_schema.py` 가 `arcon_ext.ttl`·`lake_meta.ttl` 도 읽어 클래스·`rdfs:subClassOf`·`owl:TransitiveProperty`·`rdfs:subPropertyOf` 를 채우도록 확장. 다음 컬럼에 `REFERENCES onto.class ... DEFERRABLE INITIALLY DEFERRED` 추가: `catalog.mapping.target_class_iri`, `catalog.quality_rule.target_class_iri`, `gov.access_policy.target_class_iri`, `gov.action_policy.trigger_class_iri`, `onto.action.target_class_iri`, `sem.risk_event.event_class_iri`, `onto.link.property_iri → onto.property`.

### F17. `onto.*` PK 가 IRI 단독 — "버전마다 행을 쌓는다"와 모순 (추정)
- 위치: `20_onto.sql:235, 251` (`class_iri PRIMARY KEY`, `property_iri PRIMARY KEY`), 설계서 §4.
- 시나리오: 표준 v1.1 시드를 올리면 PK 충돌로 실패하거나(`class`), `ON CONFLICT DO NOTHING` 으로 조용히 무시된다(`property`, `90_seed:…`). 버전 간 diff·롤백 불가.
- 수정: PK 를 `(class_iri, version_id)` 로 바꾸고 `onto.current_version` (1행) + `onto.v_class` 뷰로 "현재 릴리스"를 제공. 또는 레지스트리는 항상 최신만 두고 과거 버전은 `artifact_uri` 번들로만 보관한다고 명시.

### F18. 카탈로그에 회사 범위가 없고 기술 컬럼이 등록되지 않았다 (확인됨)
- 위치: `21_catalog.sql:319-344` (`dataset` 에 enterprise 키 없음), `90_seed_ontology.sql:868-` (dataset_field 1,432 = 표준 컬럼만; 물리 컬럼 1,782).
- 시나리오: 다중 회사면 데이터셋 목록·품질 점수·계보가 전 회사에 보인다. `lake_batch_id` 등 5개 기술 컬럼은 Text-to-SQL 이 참조할 카탈로그에 없어 "이 로트는 어느 적재에서 왔나"를 설명 못 한다.
- 수정: `catalog.dataset.enterprise_id`(NULL = 공용) 추가 + RLS; `gen_schema.py` 가 기술 컬럼 5개를 `maps_to_property_iri = lake:...`(lake_meta 의 `lake:ingestBatch` 등) 로 함께 등록.

### F19. `sem.quad` 현재 사실의 유일성·인덱스 부족 (추정)
- 위치: `40_sem.sql:618-638`.
- 시나리오: 추론 작업을 재실행하면 같은 `(graph, s, p, o)` 가 `valid_to IS NULL` 로 중복 적재되고 `derivation` 근거 수가 부풀며 KPI 집계가 2배가 된다. `(graph_iri, s)` 조회와 `source_chunk_id`·`job_run_id` 역추적(FK 컬럼)에 인덱스가 없다.
- 수정:
  ```sql
  CREATE UNIQUE INDEX ux_quad_current ON sem.quad (graph_iri, s, p, coalesce(o_iri, ''), coalesce(o_literal, ''), coalesce(o_datatype,''), coalesce(o_lang,'')) WHERE valid_to IS NULL;
  CREATE INDEX ix_quad_graph_s ON sem.quad (graph_iri, s) WHERE valid_to IS NULL;
  CREATE INDEX ix_quad_chunk ON sem.quad (source_chunk_id) WHERE source_chunk_id IS NOT NULL;
  ```
  대규모면 `graph_iri` 해시 파티션 검토.

### F20. pgvector: 인덱스 하나에 NODE·CHUNK·SCHEMA 가 섞여 필터 질의 재현율이 떨어진다 (추정)
- 위치: `40_sem.sql:684-694`, pgvector 0.6.0.
- 시나리오: `WHERE index_id='chunks' ORDER BY embedding <=> $1 LIMIT 10` 은 HNSW 가 `ef_search`(기본 40)개 후보를 먼저 뽑고 그 뒤 필터하므로, 스키마 라벨 임베딩이 다수면 청크 결과가 10개 미만이거나 비기도 한다. 0.6.0 에는 iterative scan 이 없다.
- 수정: `index_id` 별 부분 인덱스(`CREATE INDEX ... USING hnsw (...) WHERE index_id = 'chunks'`) 또는 대상별 테이블 분리; 패키지를 pgvector ≥ 0.8 로 올리고 `SET hnsw.iterative_scan = relaxed_order`; `halfvec(1024)` 로 인덱스 크기 절반; 인덱스 빌드 전 `maintenance_work_mem ≥ 2GB`, `max_parallel_maintenance_workers` 설정. 1단계 자동 매핑(SCHEMA 타깃)은 수백 건이라 별도 테이블이 더 단순하다.

### F21. 마이그레이션·멱등성 부재 (확인됨)
- 위치: `apply_local.sh` 전체, `20_onto.sql`·`21_catalog.sql`·`60_gov.sql` 의 `CREATE TABLE`+`INSERT` 혼합.
- 재현: `20_onto.sql` 재적용 → `ERROR: relation "namespace" already exists`. 파일별 `-1`(단일 트랜잭션)이 없어 중간 실패 시 반쯤 적용된 상태로 남는다. 스키마 버전 테이블이 없다.
- 수정: sqitch/dbmate/Flyway 중 하나로 `V0002__...sql` 식 증분 마이그레이션 채택, 현재 12개 파일은 `V0001` 베이스라인. `apply_local.sh` 는 31 을 제외한 모든 파일에 `psql -1 -v ON_ERROR_STOP=1`, 시드 INSERT 는 `ON CONFLICT DO NOTHING`, `gov.schema_migration(version, applied_at, checksum)` 기록.

### F22. 표준 존 대형 이벤트 테이블이 파티션·보존 없이 인덱스 6개를 진다 (추정)
- 위치: `10_ksx_tables.sql:1543` `trace_parameter`(인덱스 7), `operation_start/end`(9), `alarm`(6).
- 시나리오: 86M/일의 1%만 승격해도 연 3억 행, 보존 삭제가 DELETE 밖에 없고 매 행 6개 인덱스 갱신. 
- 수정: `trace_parameter`·`alarm`·`operation_start/end` 를 `PARTITION BY RANGE (event_date_time)` 월 파티션으로(PK 에 시각이 있어 가능; 이들을 참조하는 FK 는 없어 PG16 에서 문제 없음), F12 의 인덱스 정리와 함께. 또는 `trace_parameter` 자체를 Timescale 하이퍼테이블로(ksx 스키마 안에서도 가능).

### F23. KPI 정의 문제 3건 (확인됨)
- `v_kpi_otd` (`50_mart.sql:775-776`): 첫 출고가 납기 안이면 수량과 무관하게 `on_time=TRUE`. 재현: SO-5001(2,900) 에 100개 부분출고 → TRUE. 수정: `sum(sales_quantity) >= item_quantity` 를 만족한 **마지막** 출고일 기준, 미달이면 NULL.
- `v_otd_risk_candidate` (`:808, 816`): 로트 불량 / **생산지시 수량**. 지시 1건에 로트 N개면 불량률이 1/N 로 희석된다. 수정: 분모를 `lot.lot_created_quantity`(또는 해당 실적의 `produced_quantity` 합) 로.
- `v_kpi_wip` (`:820-825`): `lot_state='End'` 로트도 재공에 포함(예시 데이터에서 OP-30 End 2,000 이 WIP 로 집계). 수정: `WHERE lot_state NOT IN ('End','Scrap','Shipped')` — 코드리스트 `cl:LotState` 기준으로 확정.

---

## 4. 낮음

- **F24** `catalog.lineage_edge` `UNIQUE (from, to, pipeline_id)` 는 `pipeline_id NULL` 이면 중복 허용(확인됨: 같은 간선 2행). `UNIQUE NULLS NOT DISTINCT` 로.
- **F25** `sem.identity_decision CHECK (left_iri < right_iri)` 는 DB 콜레이션에 따라 결과가 달라 애플리케이션 정렬과 어긋날 수 있다(추정). `left_iri COLLATE "C" < right_iri COLLATE "C"`.
- **F26** `lake_shacl_status` 에 CHECK 없음(`10_ksx_tables` 전 테이블), `lake_batch_id`·`lake_source_system` 이 주석만 있고 FK 없음(확인됨: ksx CHECK 0개). 생성기에 `CHECK (lake_shacl_status IN ('PENDING','CONFORMS','VIOLATION'))` 추가; FK 는 적재 성능상 생략해도 되나 품질 규칙으로 고아 배치를 점검.
- **F27** `apply_local.sh:7` `createdb || true` 가 권한 오류도 삼킨다; 마지막 줄의 샘플 뷰 조회는 운영 적용 시 실패한다(95 를 뺄 때). `--with-sample` 플래그로 분리.
- **F28** raw 존은 "append-only" 인데 `lake_loader` 에 raw UPDATE/DELETE 가 있다(확인됨). 재적재는 새 배치로만 하고 `REVOKE UPDATE, DELETE ON ALL TABLES IN SCHEMA raw FROM lake_loader`; 보존 삭제는 파티션 DROP 으로.
- **F29** TimescaleDB 용량(추정): 86M 행/일 × (힙 ~90B + PK 인덱스 ~80B) ≈ 15GB/일, 압축 전 7일 ≈ 100GB. 압축 지연을 1~2일로, 청크를 6~12시간으로 줄이거나 `equipment_id/parameter_id` 를 정수 대리키로 바꿔 PK 를 줄일 것. `compress_segmentby` 3컬럼은 세그먼트당 행 수가 적어지면(설비×파라미터 25만 조합이면 하루 344행) 압축률이 떨어지므로 `equipment_id` 만 세그먼트로 두는 실험 권장. 압축 청크로의 지연 도착(7일 이후) INSERT 는 PK 때문에 세그먼트 해제가 일어나 느리다.
- **F30** `catalog.source_document UNIQUE (sha256)` 는 같은 PDF 가 두 데이터셋에 속할 수 없게 한다. `UNIQUE (dataset_id, sha256)` 또는 document↔dataset N:M.
- **F31** `catalog.dataset_field.mapping_status DEFAULT 'APPROVED'` 는 자동 매핑(embedding/llm) 결과도 기본 승인으로 들어가 HITL 큐(`mapping_review`) 취지와 어긋난다. 기본값 `PROPOSED`, 시드만 명시적으로 APPROVED.

---

## 5. 점검했으나 문제 없음 (참고)

- `ksx` 70 테이블 모두 RLS 활성 + `p_scope` 정책, `site_id`·`plant_id` NOT NULL(69/68 테이블), 기술 컬럼 5개 70/70 (확인됨).
- `ksx` FK 567개 전부 적용, 복합 FK 인덱스 누락 0 (확인됨). `catalog.dataset_field.maps_to_property_iri` 1,432/1,432 가 `onto.property` 에 존재 (확인됨).
- `gov.scope_ok` 는 SQL 함수로 인라인되어 `enterprise_id` 가 Index Cond 에 들어간다. 90만 행에서 `pk_trace_parameter` 로 `(enterprise_id, equipment_id, parameter_id, event_date_time)` 범위 스캔 (확인됨). `app.enterprise_id` 미설정 시 0건 (확인됨).
- 역할 그랜트: `lake_app` 은 raw 접근 없음, `lake_ml` 은 raw SELECT 만, 객체 소유자는 postgres 단일 (확인됨).
- `31_raw_timescale.sql`: PK 에 `ts` 포함, 압축 `segmentby ∪ orderby` 가 PK 를 덮음, 연속 집계가 단순 집계 + `time_bucket` GROUP BY, 정책 함수 시그니처 2.x 와 일치, 트랜잭션 밖 실행 (추정 — 실행 불가).
- `v_lot_genealogy` 순환 방지·깊이 제한, `UNIQUE NULLS NOT DISTINCT`(PG15+), `gen_random_uuid()`(PG13+) 사용 적정.

## 6. 설계 적합성 소견

- **존 분리**는 유지된다. 다만 "raw → ksx" 연결이 `lake_batch_id` 주석 수준이고(F26), "ksx → sem" 은 `quad` 에 회사 범위가 없어(F2) 격리 모델이 존마다 다르다. 범위 키(회사·사업장·공장)를 7개 스키마 공통 규약으로 선언하고 `gen_schema.py`·수기 파일 모두 같은 정책 함수를 쓰게 하면 일관성이 생긴다.
- **`catalog.dataset.represents_class_iri`** 는 std/raw 데이터셋에선 잘 작동하지만 KG(`sem.abox.*`)·마트 데이터셋은 NULL 이라 "로트 관련 데이터셋 전부" 질의가 KG 를 놓친다. `catalog.dataset_class (dataset_id, class_iri, role)` N:M 보조 테이블을 권장.
- **`sem.quad` tier** 는 적절하다. `derivation.from_facts BIGINT[]` 는 참조 무결성이 없으므로 `valid_to` 닫힌 근거를 가리키는 경우를 품질 규칙으로 점검할 것.
- **onto 레지스트리**는 "TTL 이 원본" 원칙과 맞지만 생성기가 코어 TTL 만 읽어 확장·계층·공리가 빠졌다(F16). 레지스트리를 쓰는 소비자(정책·액션·리스크)가 전부 arcon 클래스를 가리키므로 이 공백이 가장 먼저 드러난다.
