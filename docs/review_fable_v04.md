# 2단계 스키마 v0.4 재검증 — Fable 리뷰 31건 수정 확인 + 신규 발견

재검증 2026-10-14 · 대상 `02_schema/*.sql` v0.4, `tools/gen_schema.py`, `tools/apply_local.sh` · 환경: 로컬 PG 16.15 + pgvector 0.6.0, TimescaleDB 없음.

방법: 빈 DB `lake_review` 에 `ALLOW_TS_FALLBACK=1 apply_local.sh` 로 전체 적용(무오류, RLS 누락 0, 스모크 통과) → GLOBEX(2번째 회사) 데이터·사용자 추가 → 실제 접속 역할(`svc_app LOGIN IN ROLE lake_app`, `svc_loader LOGIN IN ROLE lake_loader`, 설계서 §7 절차 그대로)로 접속해 `SET LOCAL app.*` 후 재현. 생성기는 스크래치에서 재실행해 10·11·90 이 커밋본과 byte-identical 임을 diff 로 확인. 테스트 역할은 끝에 삭제.

판정 집계: 해결 22 · 부분 해결 7 · 미해결 2.

핵심: 구조적 수정(시퀀스·범위 키·뷰 로직·파티션·생성기)은 대체로 유효. 그러나 v0.4 가 새로 넣은 보안 함수 경로에 구멍이 있다 — 에이전트 질의 실행기 우회(N1), 승인 함수의 NULL 논리 결함(N2), 정책 재적용의 광역 배타 잠금(N3), 설계서대로 만든 적재 계정의 적재 실패(N4).

표기: 확인됨 = SQL 실행 재현 · 추정 = 코드 판단.

---

## (a) F1–F31 판정표

| # | 판정 | 근거 (질의 → 결과) |
|---|---|---|
| F1 | 해결 | svc_app: `INSERT INTO gov.audit_log(channel,action)` → audit_id=2, enterprise_id=ACME, user_id=u-kim. svc_loader: `sem.quad` INSERT → quad_id=5, `catalog.quality_violation` → violation_id=1 (확인됨) |
| F2 | 부분 해결 | ACME 범위에서 quad·named_graph·embedding_item·document_chunk·source_system·dataset·dataset_field 의 GLOBEX 행 0건 ✔. 단 범위 키 없는 `sem.identity_decision`·`sem.alias`·`catalog.lineage_edge`·`catalog.job_run`·`catalog.pipeline` 은 전사 노출 → N5 (확인됨) |
| F3 | 해결 | `plant_ids=''`→0, `' P9, P1 '`→4, `'*'`→4, enterprise 미설정→0 (확인됨) |
| F4 | 미해결 | `run_agent_query` 다중문 주입으로 RESET ROLE 후 GLOBEX 청크 열람; lake_agent 가 `SET LOCAL app.enterprise_id='GLOBEX'` 직접 실행 성공 → N1 (확인됨) |
| F5 | 해결 | EQ-07 에 12:00(270℃) 추가 → 뷰 3행, 12:00 행 lot_id NULL(공정 종료 후), 이벤트당 1행. 전전날 미완공 0801 착공 추가해도 오매칭 없음 (확인됨) |
| F6 | 해결 | 무결점 PP-9002(1000) 추가 → OP-40 PPM 34694 → 17172 (34/1980). 분모 별도 집계 LEFT JOIN 확인 (확인됨) |
| F7 | 해결 | mart 뷰 8/8 `reloptions={security_invoker=true}`. 정의부에 직접 기재 (확인됨) |
| F8 | 해결 | audit_log·ts_point·ksx 이벤트 테이블 지난달~3(일14)개월 파티션 사전 생성, 재실행 시 0 추가(멱등), default 0행. 단 TIMESTAMPTZ 부모 타임존 의존 → N6 (확인됨) |
| F9 | 해결 | 확장 없이 `apply_local.sh`(FALLBACK 미설정) → 00 적용 후 exit 1 (확인됨) |
| F10 | 부분 해결 | DB·역할 타임존 Asia/Seoul 고정, 기본 세션에서 `'10:15'::timestamp = '10:15+09'` 참. 단 클라이언트가 `PGTZ=UTC`(JDBC/Airflow 흔함)면 거짓 → N7 (확인됨) |
| F11 | 해결 | `fk_bulk_begin('ksx.lot')`→11 해제, 고아 INSERT 후 `fk_bulk_end` 가 fk_lot_06 위반으로 실패·롤백, 재실행 시 11 전부 convalidated. 파티션 테이블(trace_parameter)은 begin=5→end=5 즉시검증. loader work_mem=256MB 확인 (확인됨) |
| F12 | 해결 | ksx FK 427(creator/modifier FK 0), 비파티션 인덱스 300(저가치 단독 FK 인덱스 생략, 남은 2개는 PK pk_site·pk_plant 로 정상). 생성기 재실행 diff 동일 (확인됨) |
| F13 | 해결 | 새 sem(enterprise_id 有)→정책1·0건, sem(無)→RLS 꺼짐·열림이지만 lake_app 에 GRANT 없어 접근차단, 새 ksx(無)→RLS 켜짐·0건. `rls_gaps()` 0행. 단 N8 참조 (확인됨) |
| F14 | 부분 해결 | UPDATE/DELETE/TRUNCATE 거부(파티션·부모), 타사 위조 INSERT RLS 거부, user_id/enterprise_id app.* 기본값. 단 소유자가 트리거 DISABLE 후 UPDATE 가능, 파티션 직접 TRUNCATE 허용 → N9 (확인됨) |
| F15 | 부분 해결 | decide_action: 역할없음·타사·중복 거부, 정상 승인 시 상태·승인자·감사로그 기록. 원장 직접 UPDATE 거부 ✔. 단 승인자 site/plant 범위 미검증(N10), decide_access_request 는 N2 로 뚫림 (확인됨) |
| F16 | 해결 | onto.class 117(parent 88), property 534(transitive 3, subproperty 9), link 231. IRI FK 13곳(class·property·action·dataset·mapping·quality_rule·risk_event·access_policy·action_policy). 오타 IRI risk_event INSERT 거부, refParentLot ⊑ derivedFrom. 미매핑 field 1(의도된 기술컬럼?) (확인됨) |
| F17 | 해결 | 90·91 재적용 성공, onto.class 117·link 231·APPROVED field 1782 유지(upsert·DELETE 후 재삽입) (확인됨) |
| F18 | 해결 | dataset.enterprise_id(NULL=공용)+RLS, ACME 범위 dataset 3·공용 71, 기술컬럼 5개 lake:ingestBatch 등으로 등록(dangling 0) (확인됨) |
| F19 | 해결 | 같은 현재 사실 재삽입 → ux_quad_current 위반, 9KB 리터럴 정상(md5 비교) (확인됨) |
| F20 | 해결 | index_id 별 HNSW 부분 인덱스 2개 생성, `WHERE index_id='chunks' ORDER BY <=>` 에서 플래너가 ix_emb_hnsw_… 선택(seqscan off 시) (확인됨) |
| F21 | 해결 | 재실행 시 13개 파일 "이미 적용됨", checksum 변조 파일은 "적용 후 바뀜" 경고 후 건너뜀 (확인됨) |
| F22 | 해결 | ksx 이벤트 4테이블 월 파티션+DEFAULT, 자식 직접 조회(trace_parameter_2026_10)도 ACME 만. 과거 백필이 DEFAULT 로 들어가면 해당 월 파티션 생성 불가는 여전(설계상 cron 전제) (확인됨) |
| F23 | 해결 | OTD: 100/2900 부분출고→on_time NULL, 납기 후 2900 완납→FALSE. 리스크 분모 lot_created_quantity(3.40%). WIP 에서 CLOSING/SCRAP 제외(upper()) (확인됨) |
| F24 | 해결 | pipeline NULL 같은 간선 2번째 → UNIQUE NULLS NOT DISTINCT 거부 (확인됨) |
| F25 | 해결 | `CHECK (left_iri COLLATE "C" < right_iri COLLATE "C")` 적용 (확인됨) |
| F26 | 해결 | 70/70 테이블 lake_shacl_status CHECK, 'BOGUS' INSERT 거부 (확인됨) |
| F27 | 해결 | DB 없을 때만 createdb, 샘플 조회 SAMPLE=1 가드. F9 와 함께 확인 (확인됨) |
| F28 | 해결 | svc_loader: raw.landing_record DELETE·UPDATE 거부, ingest_batch (status,record_count,…) UPDATE 만 허용 (확인됨) |
| F29 | 부분 해결 | 31 pglast 파싱 8문장 OK, segmentby=(enterprise_id,equipment_id)·orderby=(parameter_id,ts DESC)·압축 2일·보존 6개월. 실행 검증 불가(추정) |
| F30 | 해결 | source_document `UNIQUE NULLS NOT DISTINCT (enterprise_id, dataset_id, sha256)` (확인됨) |
| F31 | 해결 | dataset_field.mapping_status DEFAULT 'PROPOSED', 시드 1782 APPROVED 명시 (확인됨) |

---

## (b) 신규 발견 (N1–N10)

### N1. `gov.run_agent_query` 다중문 주입으로 범위·역할 탈출 (심각, 확인됨)
- 위치: `60_gov.sql` 없음 — `70_rls.sql:156-166` `gov.run_agent_query`.
- 문제: 방어가 (1) 서브쿼리 래핑 (2) 정규식 `\m(set_config|…)` 차단 (3) `rtrim(p_sql, '; ')` 뿐이다. 래퍼 `SELECT * FROM (%s) q LIMIT %s` 의 괄호를 닫고 세미콜론으로 문장을 더 붙이면 `EXECUTE` 가 다중 문장을 그대로 실행한다. `RESET ROLE` 는 lake_agent 를 로그인 역할(=lake_app 멤버)로 되돌려 범위 변경·카탈로그 접근을 모두 연다. 정규식은 `set_config` 만 막고 `SET`/`RESET ROLE` 은 못 막는다.
- 재현(lake_agent, READ ONLY 트랜잭션):
```
SELECT gov.run_agent_query(
 'SELECT 1) q LIMIT 1) t; RESET ROLE; SET LOCAL app.enterprise_id = ''GLOBEX'';
  SELECT coalesce(jsonb_agg(t),''[]'') FROM (SELECT current_user u, chunk_text FROM catalog.document_chunk) t --');
→ [{"u":"svc_app","chunk_text":"GLOBEX 단가 1,250원/EA"}]
```
  (svc_app = 로그인 계정. 에이전트가 봐선 안 되는 타사 RAG 청크를 읽음.) 또 단순히 `SET LOCAL app.enterprise_id='GLOBEX'` 를 lake_agent 로 직접 실행해도 성공(GLOBEX 로트 1건) — F4 의 "set_config 회수"는 `SET` 명령을 막지 못한다.
- 영향: F4 가 미해결. 프롬프트 인젝션 한 줄로 회사 경계가 뚫린다.
- 수정(SQL): 문자열 방어를 버리고 파서로 단일 SELECT 임을 강제한다. PG 에는 안전한 길이 세 가지:
```sql
-- (1) 동적 SQL 을 전혀 쓰지 않고 커서로 한 문장만 연다 (다중문·사이드이펙트 원천 차단)
CREATE OR REPLACE FUNCTION gov.run_agent_query(p_sql text, p_limit int DEFAULT 200)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE c refcursor; r record; rows jsonb := '[]'::jsonb; n int := 0;
BEGIN
  IF current_user <> 'lake_agent' THEN RAISE EXCEPTION 'lake_agent 전용'; END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN RAISE EXCEPTION 'READ ONLY 필요'; END IF;
  OPEN c FOR EXECUTE p_sql;          -- 세미콜론이 있으면 "cannot insert multiple commands"로 거부됨
  LOOP FETCH c INTO r; EXIT WHEN NOT FOUND OR n >= p_limit; rows := rows || to_jsonb(r); n := n+1; END LOOP;
  CLOSE c; RETURN rows;
END $$;
```
  `OPEN … FOR EXECUTE` 는 단일 질의만 받아 세미콜론 다중문을 문법 단계에서 거부한다. 추가로 `lake_agent` 가 애초에 `RESET ROLE` 로 되돌아갈 상위 권한을 갖지 않도록, 에이전트는 **lake_app 의 멤버가 아닌 별도 로그인 계정**으로 접속하고 `SET ROLE lake_agent` 가 아니라 그 자체로 lake_agent 여야 한다(현재 `GRANT lake_agent TO lake_app` + 서버가 `SET LOCAL ROLE` 하는 구조라 RESET ROLE 이 항상 상위로 복귀 가능). pgbouncer/프록시에서 전용 계정 분리.

### N2. `gov.decide_access_request` — 역할 없는 사용자가 모든 신청을 승인 (높음, 확인됨)
- 위치: `60_gov.sql:204-210`.
- 문제: 소유자/스튜어드 확인이 `v_user IN (d.owner_user_id, d.steward_user_id) OR EXISTS(role_assignment …)`. 데이터셋에 owner·steward 가 NULL 이면(표준 존 시드 70개 전부 `owner_user_id IS NULL`) `v_user IN (NULL, NULL)` 은 **NULL**(FALSE 아님)이고, role_assignment 도 없으면 `NULL OR FALSE = NULL`, `IF NOT (NULL)` → `IF NULL` → 거짓이 아니라 **블록을 건너뛰어 승인 진행**. 즉 아무 역할 없는 사용자가 소유자 없는 데이터셋 신청을 승인한다.
- 재현(u-park: role_assignment 0건; std.lot owner/steward NULL):
```
SET LOCAL app.user_id='u-park';
SELECT gov.decide_access_request('…000a', true, 'park has no role');  → APPROVED
SELECT status, approver_id FROM gov.access_request WHERE request_id='…000a'; → APPROVED | u-park
```
  owner 가 있는 데이터셋(raw.mes.lot_history 에 owner=u-kim 설정)에 대해서도 u-park 승인 → APPROVED(여전히 NULL 논리 때문). decide_action 쪽은 `IN (…,'admin')` 가 NULL 아니라 영향 없음.
- 수정(SQL): NULL 을 FALSE 로 접고 OR 를 coalesce 로 감싼다.
```sql
IF NOT ( v_user = d.owner_user_id OR v_user = d.steward_user_id
         OR EXISTS (SELECT 1 FROM gov.role_assignment ra
                     WHERE ra.user_id=v_user AND ra.enterprise_id=v_ent
                       AND ra.role_id IN ('data_steward','admin')
                       AND (ra.valid_until IS NULL OR ra.valid_until>=current_date)) )
   IS NOT TRUE THEN
  RAISE EXCEPTION '% 은 소유자·스튜어드가 아닙니다', v_user;
END IF;
```
  `IS NOT TRUE` 가 NULL·FALSE 를 모두 거부로 접는다. owner/steward 가 NULL 인 데이터셋은 애초에 승인 주체가 없으므로 거부되는 게 옳다.

### N3. `gov.apply_scope_policies()` 가 109개 테이블에 ACCESS EXCLUSIVE 잠금 — 매일·모든 DDL 에서 (높음, 확인됨)
- 위치: `70_rls.sql:61-104`(함수), `00_schemas.sql`(ensure_partitions 가 호출), `70_rls.sql:124-141`(이벤트 트리거가 호출).
- 문제: 함수가 매번 전체 대상 테이블에 `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `DROP/CREATE POLICY` 를 무조건 실행한다(이미 켜져 있어도). 이 DDL 은 ACCESS EXCLUSIVE 잠금을 잡는다. 측정:
```
BEGIN; SELECT gov.apply_scope_policies();  -- 반환 109
SELECT mode,count(*) FROM pg_locks … → AccessExclusiveLock | 109, AccessShareLock | 109
```
  이 함수는 (1) 매일 cron `ensure_partitions` 가 새 파티션을 만들 때마다, (2) `on_create_table` 이벤트 트리거로 ksx/sem/catalog 에 **테이블이 생길 때마다** 호출된다. 운영 중 `ksx.lot` 에 AccessShare 를 쥔 세션이 있으면 전체가 막힌다(lock_timeout 2s 로 재현: `ERROR: canceling statement due to lock timeout … ALTER TABLE ksx.lot ENABLE ROW LEVEL SECURITY`). 파티션 하나 추가에도 109 테이블 전부를 다시 잠근다.
- 영향: 감사로그·landing_record 월 파티션 생성(매일)이 운영 트래픽과 잠금 경합 → 간헐적 쿼리 정지. 대형 테이블일수록 치명적.
- 수정(SQL): 이미 적용된 것은 건너뛴다.
```sql
-- ENABLE 은 relrowsecurity=false 일 때만
IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = format('%I.%I',r.nspname,r.relname)::regclass) THEN
   EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.nspname, r.relname);
END IF;
-- 정책은 존재하고 정의가 같으면 DROP/CREATE 생략 (pg_policy 비교) — 또는
-- 이벤트 트리거/ensure_partitions 는 "방금 만든 객체"에만 정책을 걸도록 대상 인자를 받게 분리
```
  최소한 ensure_partitions 는 새로 만든 파티션에만 정책을 상속시키도록 범위를 좁혀야 한다(현재는 made>0 이면 전체 재적용).

### N4. 설계서 §7 대로 만든 적재 계정이 RLS 로 적재 실패 (높음, 확인됨)
- 위치: `70_rls.sql:26`(lake_loader BYPASSRLS), 설계서 §7("NOLOGIN 으로 만들어지므로 실제 접속 계정을 만들어 이 역할을 부여").
- 문제: BYPASSRLS 는 **역할 속성**이라 멤버십으로 상속되지 않는다. 운영자가 `CREATE ROLE svc_loader LOGIN IN ROLE lake_loader` 로 만들고 그 계정으로 접속하면 BYPASSRLS 가 적용되지 않아 ksx 적재가 RLS 로 막힌다.
- 재현(svc_loader, SET ROLE 없이):
```
INSERT INTO ksx.enterprise(enterprise_id,enterprise_name) VALUES ('NEWCO','x');
→ ERROR: new row violates row-level security policy for table "enterprise"
```
  `SET ROLE lake_loader` 를 명시해야만 통과(visible_lots 5). 설계서는 이 단계를 적지 않았고, timezone/work_mem GUC 는 상속되지만 BYPASSRLS 는 안 된다.
- 수정: (1) 실제 적재 계정 자체에 `ALTER ROLE svc_loader BYPASSRLS` 를 부여하라고 §7 에 명시, 또는 (2) 적재 파이프라인이 트랜잭션마다 `SET ROLE lake_loader` 를 반드시 실행하도록 규약화. 스모크 테스트도 `SET ROLE lake_loader` 로 돌려 이 함정을 못 잡았다 — LOGIN 멤버 계정으로 도는 스모크를 추가할 것.

### N5. sem·catalog 의 범위 키 없는 보조 테이블이 전사 노출 (중간, 확인됨)
- 위치: `40_sem.sql:58-79`(`identity_decision`·`alias`), `21_catalog.sql:118-139`(`pipeline`·`job_run`·`lineage_edge`).
- 문제: F2 수정이 enterprise_id 컬럼이 있는 테이블만 격리한다. 이들에는 범위 키가 없어 lake_app/lake_agent 에 SELECT 가 열려 있고 RLS 도 없다. `lineage_edge.field_map` 은 타사 원천 컬럼명을, `job_run.error_message` 는 실패 레코드 PK·값을, `alias` 는 타사 엔티티 별칭을, `identity_decision` 은 타사 IRI 를 노출한다.
- 재현(ACME 범위): 위 5개 테이블에서 GLOBEX 행이 그대로 조회됨(판정표 F2 근거).
- 수정: 민감한 3개(identity_decision·lineage_edge·job_run)는 enterprise_id 추가 후 `apply_scope_policies` 대상에 포함. 또는 lake_app/lake_agent 의 이들 테이블 SELECT 를 회수하고 서버 API 경유로만.

### N6. 파티션 경계가 세션 타임존에 의존 — TIMESTAMPTZ 부모 (중간, 확인됨)
- 위치: `00_schemas.sql` `gov.ensure_partitions` (`d timestamptz := date_trunc(p_unit, now()) …`).
- 문제: audit_log·landing_record 는 TIMESTAMPTZ 파티션 키다. 경계는 세션 타임존으로 해석된다. 기본(Asia/Seoul)은 `…00:00:00+09` 로 생성되지만, cron 이 UTC 세션으로 돌면 `…00:00:00+00` 경계가 생겨 기존 월과 9시간 겹친다:
```
SET timezone='UTC'; SELECT gov.ensure_partitions('gov.audit_log','month',4);
→ audit_log_2027_02 FOR VALUES … ('2027-02-01 00:00:00+00') …
그 뒤 Asia/Seoul 세션에서 ensure → WARNING: audit_log_2027_03 would overlap audit_log_2027_02
```
  겹침 경계는 이후 월 생성을 영구 차단하고, KST 자정~09:00 행이 엉뚱한 월로 간다.
- 수정: 함수 본문 첫머리에 `SET LOCAL timezone='Asia/Seoul'` 를 넣거나 `d` 를 `date_trunc(p_unit, now() AT TIME ZONE 'Asia/Seoul')` 로 KST 고정 + 경계를 `timestamp` 리터럴로 포맷. ALTER ROLE 로 lake_* 는 KST 지만 cron 실행 계정(postgres/pg_cron)은 KST 보장이 없다.

### N7. KST 벽시계 규약이 클라이언트 타임존 override 에 취약 (중간, 확인됨)
- 위치: `70_rls.sql:33-37`(역할 타임존), 설계서 F10.
- 문제: 역할에 `SET timezone='Asia/Seoul'` 를 걸었지만, JDBC(`stringtype`/`PGTZ`)·libpq `PGTZ`·`SET TIME ZONE` 한 줄이면 세션 타임존이 바뀌고 역할 설정을 덮는다. 그 순간 TIMESTAMP(KST 벽시계) vs TIMESTAMPTZ 비교가 9시간 어긋난다:
```
PGTZ=UTC psql -U svc_app → show timezone = UTC;  '10:15'::timestamp = '10:15+09' → f
```
  Airflow/JDBC 커넥션이 UTC 로 뜨는 건 흔하다. 승격 SQL `ts AT TIME ZONE 'Asia/Seoul'` 은 명시적이라 안전하지만, mart 뷰 `v_kpi_equipment_time_util` 의 `execution_start_date_time::date` 등 TIMESTAMP↔TIMESTAMPTZ 가 암묵 섞이는 지점은 깨진다.
- 수정: 비교·캐스팅이 일어나는 경계를 전부 명시 변환으로(`AT TIME ZONE`), 또는 커넥션 풀 레벨에서 `options=-c timezone=Asia/Seoul` 를 강제하고 앱이 타임존을 바꾸지 못하게. 설계서에 "클라이언트가 타임존을 바꾸면 규약이 깨진다"를 경고로 남길 것.

### N8. 이벤트 트리거가 비소유자 DDL 에서 실패 → 트랜잭션 전체 롤백 (중간, 확인됨)
- 위치: `70_rls.sql:124-141` `gov.on_create_table`.
- 문제: 트리거가 `gov.apply_scope_policies()` 를 호출하는데 이 함수는 테이블 소유자 권한이 필요하다. 소유자(postgres)가 아닌 역할이 ksx/sem/catalog 에 테이블을 만들면 트리거가 `ERROR: permission denied for schema gov` 로 실패하고 **CREATE TABLE 자체가 롤백**된다.
- 재현: `GRANT CREATE ON SCHEMA sem TO dba_tmp; SET ROLE dba_tmp; CREATE TABLE sem.t_dba(...)` → `permission denied for schema gov`, 테이블 미생성(count 0).
- 영향: 마이그레이션을 비소유자 DBA 계정으로 돌리면 ksx/sem/catalog DDL 이 전부 실패. apply_scope_policies 가 SECURITY DEFINER 가 아니라서 그렇다.
- 수정: `gov.apply_scope_policies()`·`gov.on_create_table()` 을 `SECURITY DEFINER SET search_path=pg_catalog,gov` 로 바꾸고 EXECUTE 를 제한. 단 DEFINER 로 하면 임의 사용자가 트리거를 통해 ALTER 를 유발하므로, 대상 스키마(ksx/sem/catalog)로 한정된 현재 로직은 유지해도 안전.

### N9. 감사로그 불변성 — 소유자 우회·파티션 직접 TRUNCATE (중간, 확인됨)
- 위치: `60_gov.sql:110-117`.
- 문제: (1) `trg_audit_immutable` 은 소유자도 `ALTER TABLE … DISABLE TRIGGER` 후 UPDATE/DELETE 가능 — 재현: `ALTER TABLE gov.audit_log DISABLE TRIGGER trg_audit_immutable; UPDATE …` 성공. (2) TRUNCATE 트리거는 부모에만 걸려 있어 자식 파티션 직접 `TRUNCATE gov.audit_log_2026_10` 은 허용됨(재현: "TRUNCATE partition directly: allowed"). 설계서는 "소유자 포함 차단"이라고 적었으나 DISABLE 로 뚫린다.
- 수정: 진짜 불변성은 트리거로 못 만든다. (1) 소유자를 접속 불가 `lake_owner` 로 분리(설계서도 예고만 함), (2) 보존은 DETACH 후 외부 보관, (3) 파티션 자식에도 TRUNCATE 트리거를 걸거나 자식 TRUNCATE 권한 회수, (4) 진짜 무결성은 pgaudit + append-only 외부 저장(WORM)로. "트리거가 소유자도 막는다"는 과장된 서술이므로 설계서 문구 수정.

### N10. decide_action 이 승인자의 site/plant 범위를 검증하지 않음 (낮음, 확인됨)
- 위치: `60_gov.sql:175-180`.
- 문제: 승인 권한을 `role_assignment` 의 (user, enterprise, role) 로만 본다. role_assignment 에는 site_id/plant_id 가 있지만(u-kim 은 HQ/P2 로 한정) action_execution 에는 site/plant 컬럼이 없어 비교 자체가 불가. 재현: u-kim(QE, HQ/P2) 이 ACME 전체 범위 execution 을 승인 → APPROVED. P2 로 한정된 품질엔지니어가 다른 공장 액션을 승인한다.
- 수정: action_execution 에 site_id/plant_id 를 넣고(risk_event 에서 복사) 승인 시 `gov.scope_ok` 또는 role_assignment 범위와 대조. 또는 범위 무시가 의도라면 설계서에 명시.

---

## 참고: 정상 확인 / 추가 소견
- 생성기(gen_schema.py) 재실행으로 10·11·90 이 커밋본과 byte-identical. FK 427·인덱스 300·field 1782·링크 231·클래스 117 수치 일치. `DELETE FROM onto.link` + 전체 재삽입은 멱등.
- run_agent_query 정규식은 리터럴 속 `;`(`LIKE '%;%'`)에 오탐 없음(rtrim 만, 내부 세미콜론 영향 없음) — 단 N1 때문에 전면 교체 권장.
- lake_ml 은 lake_app 멤버라 decide_action EXECUTE 상속(has_function_privilege t). 의도라면 무방하나 ML 학습 계정에 승인권이 붙는 건 재검토.
- 미해결 2건(F4=N1, decide_access_request=N2)과 신규 높음 3건(N3·N4 + N2)은 운영 투입 전 차단 권고.
