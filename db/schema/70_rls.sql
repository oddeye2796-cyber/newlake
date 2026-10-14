-- =============================================================================
-- 행 단위 보안(RLS) · DB 역할 — 기본 적용 (온프레미스 PostgreSQL)
-- 2026-10-14 v0.3: Fable 리뷰 F1·F2·F3·F4·F7 반영
-- 2026-10-14 v0.4: F10 타임존, F11 적재 메모리, F13 RLS 자동 적용·누락 검사, F14 감사로그, F15 승인 함수, F18 카탈로그 범위, F22 파티션, F28 원천 append-only
--
-- 역할 (클러스터 단위, 없을 때만 만든다. 비밀번호·LOGIN 은 운영에서 따로 부여)
--   lake_loader   적재 파이프라인. BYPASSRLS. raw·ksx·sem·catalog 쓰기
--                 BYPASSRLS 는 역할 속성이라 멤버에게 상속되지 않는다 (재검토 N4). 접속 계정은
--                 CREATE ROLE svc_loader LOGIN BYPASSRLS IN ROLE lake_loader; 처럼 계정 자체에 BYPASSRLS 를 준다.
--   (에이전트)    LLM SQL 은 lake_app 멤버가 아닌 전용 접속 계정(예: svc_agent LOGIN IN ROLE lake_agent)으로 실행하는 것을 권장한다.
--                 그러면 RESET ROLE 을 해도 lake_app 권한으로 되돌아갈 수 없다 (재검토 N1 심층 방어).
--   lake_app      콘솔·API 서버(신뢰된 코드). RLS 적용. 범위를 트랜잭션마다 주입
--   lake_ml       ML 학습. lake_app + 원천 존 읽기(승인된 경우에만 부여)
--   lake_agent    LLM/Text-to-SQL 이 만든 SQL 을 실행하는 역할. 읽기 전용, 범위를 스스로 못 바꿈
--
-- 범위 주입 규칙 (서버 코드만 한다. 커넥션 풀에서도 새지 않도록 SET LOCAL):
--   BEGIN; SET LOCAL app.enterprise_id = 'ACME'; SET LOCAL app.site_ids = 'HQ'; SET LOCAL app.plant_ids = 'P1'; ... COMMIT;
--   회사 안 전체는 '*' 를 명시한다. 미설정·빈 문자열은 0건(거부)이다.
--
-- LLM 이 만든 SQL 실행 (F4):
--   BEGIN READ ONLY; SET LOCAL app.*=...; SET LOCAL ROLE lake_agent; SELECT gov.run_agent_query($sql); COMMIT;
--   run_agent_query 는 SQL 을 서브쿼리로 감싸 단일 SELECT 만 허용한다(SET·RESET·다중문 불가).
--   lake_agent 에는 set_config 실행 권한이 없어 범위·역할을 바꿀 수 없다.
-- SPARQL 경로는 Named Graph + OPA 가 같은 키로 같은 역할을 한다.
-- =============================================================================
SET client_min_messages = warning;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lake_loader') THEN CREATE ROLE lake_loader NOLOGIN BYPASSRLS; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lake_app')    THEN CREATE ROLE lake_app NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lake_ml')     THEN CREATE ROLE lake_ml NOLOGIN IN ROLE lake_app; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lake_agent')  THEN CREATE ROLE lake_agent NOLOGIN; END IF;
END $$;
GRANT lake_agent TO lake_app;   -- 서버가 SET LOCAL ROLE lake_agent 로 내려갈 수 있게

-- 세션 타임존 고정 (리뷰 F10): ksx 의 TIMESTAMP 는 한국 표준시 벽시계. UTC 컨테이너의 적재기도 같은 시각으로 읽고 쓴다.
ALTER ROLE lake_loader SET timezone = 'Asia/Seoul';
ALTER ROLE lake_app    SET timezone = 'Asia/Seoul';
ALTER ROLE lake_ml     SET timezone = 'Asia/Seoul';
ALTER ROLE lake_agent  SET timezone = 'Asia/Seoul';
-- 대량 적재 세션 메모리 (리뷰 F11). 서버 메모리에 맞게 조정.
ALTER ROLE lake_loader SET work_mem = '256MB';
ALTER ROLE lake_loader SET maintenance_work_mem = '1GB';

-- 범위 판정: '*' 만 전체 허용, 미설정·빈 값은 거부, 목록의 공백은 무시 (F3)
-- p_site / p_plant 가 NULL 인 행(회사 단위 기준정보, 범위가 회사까지인 리스크 이벤트)은 회사 범위만 맞으면 보인다.
CREATE OR REPLACE FUNCTION gov.scope_ok(p_ent text, p_site text, p_plant text) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT p_ent IS NOT NULL AND p_ent = nullif(current_setting('app.enterprise_id', true), '')
     AND (current_setting('app.site_ids', true) = '*'
          OR p_site IS NULL
          OR p_site = ANY (string_to_array(replace(current_setting('app.site_ids', true), ' ', ''), ',')))
     AND (current_setting('app.plant_ids', true) = '*'
          OR p_plant IS NULL
          OR p_plant = ANY (string_to_array(replace(current_setting('app.plant_ids', true), ' ', ''), ',')))
$$;

-- 정책 적용 함수 — 새 테이블·새 파티션을 만든 뒤에도 다시 부를 수 있다 (재실행 안전)
-- 대상 (리뷰 F2·F13·F18·F22):
--   ksx 전부(파티션 자식 포함 — 자식을 직접 조회해도 새지 않게), sem·catalog 에서 enterprise_id 를 가진 테이블,
--   gov.action_execution·gov.access_request. enterprise_id 가 NULL 허용이면 NULL = 공용(모두에게 보임).
--   gov.audit_log 는 따로: 회사 행만 보이고 NULL(플랫폼) 행은 숨긴다.
--   enterprise_id 가 없는 ksx 테이블은 RLS 만 켜고 정책을 두지 않는다 → 앱 역할에는 0건(닫힌 채로 실패).
--   p_force = false(기본): RLS 가 이미 켜져 있고 p_scope 정책이 있는 테이블은 건너뛴다 → 새 테이블·새 파티션에만 잠금 (재검토 N3)
--   p_force = true: 전부 다시 만든다(정책 정의를 바꾼 마이그레이션에서만, 점검 시간에).
--   SECURITY DEFINER (재검토 N8): 소유자가 아닌 DBA 가 테이블을 만들어도 이벤트 트리거가 정책을 걸 수 있게.
CREATE OR REPLACE FUNCTION gov.apply_scope_policies(p_force boolean DEFAULT false) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE r record; has_site boolean; has_plant boolean; n int := 0;
BEGIN
  FOR r IN SELECT n.nspname, c.relname, a.attnotnull AS ent_required, a.attname IS NOT NULL AS has_ent,
                  c.relrowsecurity, EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid AND p.polname = 'p_scope') AS has_policy
             FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             LEFT JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = 'enterprise_id' AND NOT a.attisdropped
            WHERE c.relkind IN ('r','p')
              AND (n.nspname = 'ksx'
                   OR (n.nspname IN ('sem','catalog') AND a.attname IS NOT NULL AND NOT c.relispartition)
                   OR (n.nspname = 'gov' AND c.relname IN ('action_execution','access_request'))) LOOP
    CONTINUE WHEN NOT p_force AND r.relrowsecurity AND (r.has_policy OR NOT r.has_ent);
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', r.nspname, r.relname);
    EXECUTE format('DROP POLICY IF EXISTS p_scope ON %I.%I', r.nspname, r.relname);
    IF r.has_ent THEN
      SELECT bool_or(attname = 'site_id'), bool_or(attname = 'plant_id') INTO has_site, has_plant
        FROM pg_attribute WHERE attrelid = format('%I.%I', r.nspname, r.relname)::regclass AND attnum > 0 AND NOT attisdropped;
      EXECUTE format('CREATE POLICY p_scope ON %I.%I USING (%s gov.scope_ok(enterprise_id, %s, %s))', r.nspname, r.relname,
                     CASE WHEN r.ent_required THEN '' ELSE 'enterprise_id IS NULL OR' END,
                     CASE WHEN has_site THEN 'site_id' ELSE 'NULL' END,
                     CASE WHEN has_plant THEN 'plant_id' ELSE 'NULL' END);
    END IF;
    n := n + 1;
  END LOOP;
  -- 범위를 부모를 통해 판정하는 테이블
  FOR r IN SELECT * FROM (VALUES
      ('sem.quad',                  'EXISTS (SELECT 1 FROM sem.named_graph g WHERE g.graph_iri = quad.graph_iri)'),   -- named_graph 의 RLS 가 판정
      ('sem.derivation',            'EXISTS (SELECT 1 FROM sem.quad q WHERE q.quad_id = derivation.quad_id)'),
      ('catalog.dataset_field',     'EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = dataset_field.dataset_id)'),
      ('catalog.quality_run',       'EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = quality_run.dataset_id)'),
      ('catalog.quality_violation', 'EXISTS (SELECT 1 FROM catalog.quality_run q WHERE q.quality_run_id = quality_violation.quality_run_id)'),
      ('gov.audit_log',             'gov.scope_ok(enterprise_id, NULL, NULL)')   -- 회사 행만, NULL(플랫폼) 행은 숨김
    ) v(tbl, expr) LOOP
    CONTINUE WHEN NOT p_force AND EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = r.tbl::regclass AND p.polname = 'p_scope')
                  AND (SELECT relrowsecurity FROM pg_class WHERE oid = r.tbl::regclass);
    EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', r.tbl);
    EXECUTE format('DROP POLICY IF EXISTS p_scope ON %s', r.tbl);
    EXECUTE format('CREATE POLICY p_scope ON %s USING (%s)', r.tbl, r.expr);
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;
SELECT gov.apply_scope_policies(true);
REVOKE ALL ON FUNCTION gov.apply_scope_policies(boolean) FROM PUBLIC;

-- RLS 누락 검사 (리뷰 F13). 0행이어야 한다 — db/apply.sh 와 CI 가 확인한다.
CREATE OR REPLACE FUNCTION gov.rls_gaps() RETURNS TABLE (table_name text, problem text) LANGUAGE sql STABLE AS $$
  SELECT format('%I.%I', n.nspname, c.relname), 'RLS 꺼짐'
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE c.relkind IN ('r','p') AND NOT c.relrowsecurity
     AND (n.nspname = 'ksx'
          OR (n.nspname IN ('sem','catalog') AND NOT c.relispartition
              AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'enterprise_id' AND NOT a.attisdropped)))
  UNION ALL
  SELECT format('%I.%I', n.nspname, c.relname), 'enterprise_id 가 있는데 정책 없음'
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE c.relkind IN ('r','p') AND c.relrowsecurity AND n.nspname IN ('ksx','sem','catalog')
     AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'enterprise_id' AND NOT a.attisdropped)
     AND NOT EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)
$$;

-- 새 테이블이 생기면 바로 정책을 건다 (이벤트 트리거, 슈퍼유저만 만들 수 있다).
-- ksx 의 새 테이블은 일단 RLS 를 켜서 닫고(정책이 없으면 앱 역할에 0건), 범위 키가 있으면 정책을 붙인다.
CREATE OR REPLACE FUNCTION gov.on_create_table() RETURNS event_trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE r record; touched boolean := false;
BEGIN
  FOR r IN SELECT * FROM pg_event_trigger_ddl_commands()
            WHERE object_type = 'table' AND schema_name IN ('ksx','sem','catalog') LOOP
    IF r.schema_name = 'ksx' THEN EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', r.object_identity); END IF;
    touched := true;
  END LOOP;
  IF touched THEN PERFORM gov.apply_scope_policies(); END IF;
END $$;
DO $$
BEGIN
  DROP EVENT TRIGGER IF EXISTS trg_lake_auto_rls;
  CREATE EVENT TRIGGER trg_lake_auto_rls ON ddl_command_end WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
    EXECUTE FUNCTION gov.on_create_table();
EXCEPTION WHEN insufficient_privilege THEN
  RAISE WARNING '이벤트 트리거를 만들 권한이 없습니다(슈퍼유저 필요). 마이그레이션마다 gov.apply_scope_policies() 와 gov.rls_gaps() 를 실행하세요.';
END $$;

-- mart 뷰는 50_mart.sql 에서 WITH (security_invoker = true) 로 정의한다 (F7). 아래는 안전망 + 검사.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
           WHERE n.nspname = 'mart' AND c.relkind = 'v'
             AND coalesce(c.reloptions::text, '') NOT LIKE '%security_invoker=true%' LOOP
    RAISE WARNING 'mart.% 에 security_invoker 가 없어 지금 설정합니다. 50_mart.sql 정의를 고치세요.', r.relname;
    EXECUTE format('ALTER VIEW mart.%I SET (security_invoker = true)', r.relname);
  END LOOP;
END $$;

-- LLM SQL 실행기 (F4) ---------------------------------------------------------
-- 동적 문자열을 감싸 EXECUTE 하면 괄호를 닫고 ; 로 RESET ROLE·SET 을 이어 붙일 수 있었다 (재검토 N1).
-- OPEN ... FOR EXECUTE 는 질의 한 개만 받는다(다중문은 문법 단계에서 거부) → SET·RESET·DML 이 끼어들 수 없다.
CREATE OR REPLACE FUNCTION gov.run_agent_query(p_sql text, p_limit int DEFAULT 200) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE c refcursor; r record; rows jsonb := '[]'::jsonb; k int := 0;
BEGIN
  IF current_user <> 'lake_agent' THEN RAISE EXCEPTION 'lake_agent 역할로만 실행합니다'; END IF;
  IF NOT current_setting('transaction_read_only')::boolean THEN RAISE EXCEPTION '읽기 전용 트랜잭션(BEGIN READ ONLY)에서만 실행합니다'; END IF;
  IF p_sql ~* '\m(set_config|dblink|lo_\w+|pg_read\w*|pg_ls_dir|pg_stat_file)\M' THEN RAISE EXCEPTION '허용되지 않는 함수가 포함되어 있습니다'; END IF;
  OPEN c NO SCROLL FOR EXECUTE rtrim(p_sql, '; ' || chr(10) || chr(13) || chr(9));
  LOOP
    FETCH c INTO r;
    EXIT WHEN NOT FOUND OR k >= p_limit;
    rows := rows || jsonb_build_array(to_jsonb(r));
    k := k + 1;
  END LOOP;
  CLOSE c;
  RETURN rows;
END $$;
REVOKE ALL ON FUNCTION gov.run_agent_query(text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.run_agent_query(text, int) TO lake_agent;

-- 범위를 바꾸는 함수는 신뢰된 역할만 (lake_agent 는 SET LOCAL ROLE 이후 범위·역할 변경 불가)
REVOKE EXECUTE ON FUNCTION pg_catalog.set_config(text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pg_catalog.set_config(text, text, boolean) TO lake_app, lake_loader, lake_ml;

-- 권한 (F1: 시퀀스 포함, 이후 만들 객체에도 기본 권한) -------------------------
GRANT USAGE ON SCHEMA raw, ksx, sem, mart, onto, catalog, gov TO lake_loader;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ksx, sem, catalog TO lake_loader;
-- 원천 존은 append-only (리뷰 F28): 추가만. 재적재는 새 배치로, 보존 삭제는 파티션 DROP 으로. 배치 상태 전이만 UPDATE 허용.
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA raw TO lake_loader;
GRANT UPDATE (status, record_count, byte_size, checksum) ON raw.ingest_batch TO lake_loader;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA raw, ksx, sem, catalog, onto TO lake_loader;
GRANT SELECT ON ALL TABLES IN SCHEMA onto, mart TO lake_loader;
GRANT INSERT ON gov.audit_log TO lake_loader;

GRANT USAGE ON SCHEMA ksx, sem, mart, onto, catalog, gov TO lake_app;
GRANT SELECT ON ALL TABLES IN SCHEMA ksx, sem, mart, onto, catalog TO lake_app;
GRANT SELECT ON gov.action_policy, gov.access_policy TO lake_app;
GRANT SELECT, INSERT ON gov.access_request, gov.audit_log, gov.action_execution TO lake_app;
-- 승인·반려는 상태 전이 함수로만 (리뷰 F15). 원장 UPDATE 권한은 주지 않는다.
REVOKE ALL ON FUNCTION gov.decide_action(uuid, boolean, text), gov.decide_access_request(uuid, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.decide_action(uuid, boolean, text), gov.decide_access_request(uuid, boolean, text) TO lake_app;
-- 감사로그는 누구도 고치거나 지울 수 없다 (리뷰 F14 — 트리거가 소유자도 막는다)
REVOKE UPDATE, DELETE, TRUNCATE ON gov.audit_log FROM PUBLIC, lake_app, lake_loader;
-- 대량 적재 FK 해제 함수 (리뷰 F11)
REVOKE ALL ON FUNCTION gov.fk_bulk_begin(regclass), gov.fk_bulk_end(regclass) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.fk_bulk_begin(regclass), gov.fk_bulk_end(regclass) TO lake_loader;
REVOKE ALL ON FUNCTION sem.ensure_embedding_hnsw() FROM PUBLIC;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA gov TO lake_app, lake_loader;
GRANT EXECUTE ON FUNCTION gov.scope_ok(text, text, text) TO lake_app, lake_loader, lake_agent;

GRANT USAGE ON SCHEMA ksx, sem, mart, onto, gov TO lake_agent;
GRANT SELECT ON ALL TABLES IN SCHEMA ksx, mart, onto TO lake_agent;
GRANT SELECT ON sem.quad, sem.named_graph, sem.risk_event TO lake_agent;   -- 임베딩 원문·문서 청크는 RAG 서버 경유로만

GRANT USAGE ON SCHEMA raw TO lake_ml;
GRANT SELECT ON ALL TABLES IN SCHEMA raw TO lake_ml;

-- 이 스크립트를 실행한 소유자가 앞으로 만드는 객체에도 같은 권한
ALTER DEFAULT PRIVILEGES IN SCHEMA ksx, sem, catalog GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lake_loader;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw GRANT SELECT, INSERT ON TABLES TO lake_loader;
ALTER DEFAULT PRIVILEGES IN SCHEMA raw, ksx, sem, catalog, onto, gov GRANT USAGE, SELECT ON SEQUENCES TO lake_loader;
ALTER DEFAULT PRIVILEGES IN SCHEMA ksx, sem, mart, onto, catalog GRANT SELECT ON TABLES TO lake_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA gov GRANT USAGE, SELECT ON SEQUENCES TO lake_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA ksx, mart, onto GRANT SELECT ON TABLES TO lake_agent;
-- 새 테이블은 이벤트 트리거가 정책을 건다. 트리거가 없는 환경이면 마이그레이션 끝에 SELECT gov.apply_scope_policies(); 를 돌리고
-- SELECT * FROM gov.rls_gaps(); 가 0행인지 확인한다.
