-- =============================================================================
-- 거버넌스 (gov) — 역할·범위, 신청·승인, API 토큰, 감사로그(12개월+), 액션 정책·실행 원장
-- 접근 범위 3-tuple(회사·사업장·공장)은 KS X 9101 기본 속성과 같은 키를 쓴다.
-- =============================================================================
CREATE TABLE gov.role (
    role_id          VARCHAR(40) PRIMARY KEY,
    label_ko         VARCHAR(100) NOT NULL,
    description      VARCHAR(500)
);
INSERT INTO gov.role VALUES
 ('admin',            '플랫폼 관리자',   '전체 설정·권한'),
 ('ontology_manager', '온톨로지 관리자', 'TBox·매핑 승인, 버전 릴리스'),
 ('data_engineer',    '데이터 엔지니어', '커넥터·파이프라인·매핑 작성'),
 ('data_steward',     '데이터 스튜어드', '품질 이슈 처리, 데이터셋 소유'),
 ('quality_engineer', '품질 엔지니어',   '불량 역추적·시정조치'),
 ('production_manager','생산관리자',    'KPI·WIP·계획 대비 실적'),
 ('analyst',          '분석가',         '조회·질의·다운로드(승인 시)'),
 ('viewer',           '조회자',         '대시보드 조회'),
 ('agent',            'AI 에이전트',     'MCP 경유 조회·액션 제안(실행은 정책 따름)');

CREATE TABLE gov.app_user (
    user_id          VARCHAR(50) PRIMARY KEY,    -- IdP subject (Keycloak 등)
    display_name     VARCHAR(100) NOT NULL,
    email            VARCHAR(200),
    personnel_id     VARCHAR(50),                -- ksx.personnel 연결(선택)
    enterprise_id    VARCHAR(50) NOT NULL,
    status           VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','LOCKED','RETIRED')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 역할 × 범위. site_id/plant_id NULL = 하위 전체
CREATE TABLE gov.role_assignment (
    user_id          VARCHAR(50) NOT NULL REFERENCES gov.app_user(user_id),
    role_id          VARCHAR(40) NOT NULL REFERENCES gov.role(role_id),
    enterprise_id    VARCHAR(50) NOT NULL,
    site_id          VARCHAR(50),
    plant_id         VARCHAR(50),
    valid_until      DATE,
    granted_by       VARCHAR(50),
    granted_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (user_id, role_id, enterprise_id, site_id, plant_id)
);

-- 데이터셋·클래스 단위 접근 정책 (ODRL → OPA 정책으로 컴파일)
CREATE TABLE gov.access_policy (
    policy_id        VARCHAR(100) PRIMARY KEY,
    role_id          VARCHAR(40) NOT NULL REFERENCES gov.role(role_id),
    target_class_iri VARCHAR(300) REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED,  -- 클래스 단위: 이 클래스를 represents 하는 모든 데이터셋
    target_dataset_id VARCHAR(150) REFERENCES catalog.dataset(dataset_id),
    max_sensitivity  VARCHAR(12) NOT NULL DEFAULT 'INTERNAL',
    actions          TEXT[] NOT NULL DEFAULT '{read}',   -- read|query|download|write|execute_action
    requires_approval BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (target_class_iri IS NOT NULL OR target_dataset_id IS NOT NULL)
);

-- 데이터 이용 신청 → 승인 워크플로
CREATE TABLE gov.access_request (
    request_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id     VARCHAR(50) NOT NULL REFERENCES gov.app_user(user_id),
    dataset_id       VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id),
    purpose          VARCHAR(1000) NOT NULL,
    requested_actions TEXT[] NOT NULL DEFAULT '{read}',
    period_from      DATE NOT NULL,
    period_to        DATE NOT NULL,
    status           VARCHAR(10) NOT NULL DEFAULT 'REQUESTED' CHECK (status IN ('REQUESTED','APPROVED','REJECTED','EXPIRED','REVOKED')),
    approver_id      VARCHAR(50) REFERENCES gov.app_user(user_id),
    enterprise_id    VARCHAR(50) NOT NULL DEFAULT nullif(current_setting('app.enterprise_id', true), ''),   -- 신청자 회사 (RLS)
    decided_at       TIMESTAMPTZ,
    decision_note    VARCHAR(1000),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (period_to >= period_from)
);

-- API 토큰 (원문 저장 금지, 해시만)
CREATE TABLE gov.api_token (
    token_id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          VARCHAR(50) NOT NULL REFERENCES gov.app_user(user_id),
    token_sha256     CHAR(64) NOT NULL UNIQUE,
    scopes           TEXT[] NOT NULL,
    issued_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at       TIMESTAMPTZ NOT NULL,
    revoked_at       TIMESTAMPTZ,
    last_used_at     TIMESTAMPTZ
);

-- 감사로그 — 월 파티션, 최소 12개월 보존 (공공 보안 기준). append-only (리뷰 F14)
--   · 행 수정·삭제·TRUNCATE(부모·각 파티션)는 트리거가 막는다. 보존 기간이 지난 월은 파티션을 DETACH 후 보관·DROP.
--   · 트리거는 실수·앱 경로를 막는 장치다. 테이블 소유자는 트리거를 끌 수 있으므로 진짜 불변성은
--     소유자를 접속 불가 lake_owner 로 분리 + pgaudit + 외부 WORM 보관으로 만든다 (재검토 N9).
--   · user_id·enterprise_id 는 서버가 트랜잭션마다 넣는 app.user_id·app.enterprise_id 에서 채운다(앱이 임의 값을 쓰지 않게).
--   · SQL 직접 접속 감사는 앱이 기록할 수 없으므로 pgaudit 확장으로 보완한다(운영 메모 §8).
CREATE TABLE gov.audit_log (
    audit_id         BIGSERIAL,
    occurred_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    enterprise_id    VARCHAR(50) DEFAULT nullif(current_setting('app.enterprise_id', true), ''),   -- 회사별 감사 추출·RLS
    user_id          VARCHAR(50) DEFAULT nullif(current_setting('app.user_id', true), ''),
    client_ip        INET,
    channel          VARCHAR(10) NOT NULL CHECK (channel IN ('UI','API','SPARQL','SQL','MCP','BATCH')),
    action           VARCHAR(30) NOT NULL,       -- login|read|query|download|approve|execute_action|mapping_approve…
    dataset_id       VARCHAR(150),
    object_ref       VARCHAR(500),               -- IRI · 테이블 PK · 질의 해시
    query_text       TEXT,                       -- SPARQL/SQL 원문 (민감 파라미터 마스킹 후)
    row_count        BIGINT,
    result           VARCHAR(10) NOT NULL DEFAULT 'OK' CHECK (result IN ('OK','DENIED','ERROR')),
    PRIMARY KEY (occurred_at, audit_id)
) PARTITION BY RANGE (occurred_at);
CREATE TABLE gov.audit_log_default PARTITION OF gov.audit_log DEFAULT;
SELECT gov.ensure_partitions('gov.audit_log', 'month', 3);
CREATE INDEX ix_audit_user ON gov.audit_log (user_id, occurred_at);
CREATE INDEX ix_audit_ent  ON gov.audit_log (enterprise_id, occurred_at);

CREATE OR REPLACE FUNCTION gov.raise_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION '%.% 는 추가만 가능합니다(append-only). 보존 만료는 파티션 DETACH 로 처리하세요.', TG_TABLE_SCHEMA, TG_TABLE_NAME;
END $$;
CREATE TRIGGER trg_audit_immutable BEFORE UPDATE OR DELETE ON gov.audit_log
    FOR EACH ROW EXECUTE FUNCTION gov.raise_immutable();
CREATE TRIGGER trg_audit_no_truncate BEFORE TRUNCATE ON gov.audit_log
    FOR EACH STATEMENT EXECUTE FUNCTION gov.raise_immutable();
-- TRUNCATE 트리거는 파티션에 상속되지 않으므로 이미 있는 파티션에도 건다 (새 파티션은 ensure_partitions 가 건다)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.oid::regclass AS part FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
            WHERE i.inhparent = 'gov.audit_log'::regclass LOOP
    EXECUTE format('CREATE TRIGGER trg_audit_no_truncate BEFORE TRUNCATE ON %s FOR EACH STATEMENT EXECUTE FUNCTION gov.raise_immutable()', r.part);
  END LOOP;
END $$;

-- 액션 실행 정책 (Decision Engine). 액션 정의는 onto.action, 여기는 "언제·누가 승인"
CREATE TABLE gov.action_policy (
    policy_id        VARCHAR(100) PRIMARY KEY,   -- 예: otd-risk
    trigger_class_iri VARCHAR(300) NOT NULL,     -- arcon:OTDRiskEvent
    condition        JSONB NOT NULL,             -- {"riskLevel":"HIGH","dueWithinDays":7}
    action_iri       VARCHAR(300) NOT NULL REFERENCES onto.action(action_iri),
    mode             VARCHAR(10) NOT NULL CHECK (mode IN ('auto','approval','notify')),
    approver_role_id VARCHAR(40) REFERENCES gov.role(role_id),
    notify_role_ids  TEXT[] NOT NULL DEFAULT '{}',
    suppress_window  INTERVAL NOT NULL DEFAULT INTERVAL '4 hours',   -- 같은 대상 중복 발화 억제
    enterprise_id    VARCHAR(50),
    enabled          BOOLEAN NOT NULL DEFAULT TRUE
);

-- 액션 실행 원장 = BOD 발신 기록 (감사·재현)
CREATE TABLE gov.action_execution (
    execution_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id        VARCHAR(100) REFERENCES gov.action_policy(policy_id),
    risk_event_id    UUID REFERENCES sem.risk_event(event_id),
    enterprise_id    VARCHAR(50) NOT NULL DEFAULT nullif(current_setting('app.enterprise_id', true), ''),   -- 승인 범위 판정
    site_id          VARCHAR(50),                -- 대상의 사업장·공장 (risk_event 에서 복사). NULL = 회사 단위 액션 (재검토 N10)
    plant_id         VARCHAR(50),
    action_iri       VARCHAR(300) NOT NULL REFERENCES onto.action(action_iri),
    target_iri       VARCHAR(500) NOT NULL,
    bod_id           UUID NOT NULL DEFAULT gen_random_uuid(),   -- KS X 9101 BODID
    verb             VARCHAR(30) NOT NULL,
    noun             VARCHAR(60) NOT NULL,
    receiver_system  VARCHAR(50),
    status           VARCHAR(12) NOT NULL DEFAULT 'PROPOSED'
                     CHECK (status IN ('PROPOSED','APPROVED','REJECTED','SENT','ACKNOWLEDGED','FAILED','SUPPRESSED')),
    requested_by     VARCHAR(50),                -- 사용자 또는 'agent:…'
    approved_by      VARCHAR(50),
    rationale        JSONB,                      -- 판정 근거(규칙·근거 사실 IRI·정책 평가 결과)
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at          TIMESTAMPTZ,
    acknowledged_at  TIMESTAMPTZ
);
CREATE INDEX ix_action_exec_target ON gov.action_execution (target_iri, created_at);

-- 액션 정책 시드는 91_seed_actions.sql (trigger_class_iri 가 onto.class 를 FK 로 가리킨다)
ALTER TABLE gov.action_policy ADD CONSTRAINT fk_action_policy_class FOREIGN KEY (trigger_class_iri)
    REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED;

-- 승인·반려는 상태 전이 함수로만 (리뷰 F15) ------------------------------------
-- lake_app 에는 두 원장의 UPDATE 권한이 없다. 함수가 (1) 승인자 = app.user_id (2) 승인자 역할·범위 (3) 허용된 전이만 확인하고 감사로그를 남긴다.
CREATE OR REPLACE FUNCTION gov.decide_action(p_execution_id uuid, p_approve boolean, p_note text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
  e gov.action_execution; v_role text; v_status text;
BEGIN
  IF v_user IS NULL OR v_ent IS NULL THEN RAISE EXCEPTION 'app.user_id 와 app.enterprise_id 가 필요합니다'; END IF;
  SELECT * INTO e FROM gov.action_execution WHERE execution_id = p_execution_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '실행 요청 % 이 없습니다', p_execution_id; END IF;
  IF e.status <> 'PROPOSED' THEN RAISE EXCEPTION '이미 처리된 요청입니다 (상태 %)', e.status; END IF;
  IF e.enterprise_id <> v_ent THEN RAISE EXCEPTION '다른 회사의 요청은 처리할 수 없습니다'; END IF;
  SELECT approver_role_id INTO v_role FROM gov.action_policy WHERE policy_id = e.policy_id;
  IF NOT EXISTS (SELECT 1 FROM gov.role_assignment ra
                  WHERE ra.user_id = v_user AND ra.enterprise_id = v_ent
                    AND ra.role_id IN (coalesce(v_role, 'admin'), 'admin')
                    -- 승인자 범위가 대상 사업장·공장을 덮어야 한다. 회사 단위 액션은 회사 전체 범위만 승인 (재검토 N10)
                    AND (ra.site_id IS NULL OR ra.site_id = e.site_id)
                    AND (ra.plant_id IS NULL OR ra.plant_id = e.plant_id)
                    AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)) THEN
    RAISE EXCEPTION '% 에게 이 요청을 승인할 역할(%)이 없습니다', v_user, coalesce(v_role, 'admin');
  END IF;
  v_status := CASE WHEN p_approve THEN 'APPROVED' ELSE 'REJECTED' END;
  UPDATE gov.action_execution
     SET status = v_status, approved_by = v_user,
         rationale = coalesce(rationale, '{}'::jsonb) || jsonb_build_object('decision_note', p_note, 'decided_at', now())
   WHERE execution_id = p_execution_id;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', CASE WHEN p_approve THEN 'approve' ELSE 'reject' END, 'action_execution:' || p_execution_id, p_note);
  RETURN v_status;
END $$;

CREATE OR REPLACE FUNCTION gov.decide_access_request(p_request_id uuid, p_approve boolean, p_note text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
  r gov.access_request; d catalog.dataset; v_status text;
BEGIN
  IF v_user IS NULL OR v_ent IS NULL THEN RAISE EXCEPTION 'app.user_id 와 app.enterprise_id 가 필요합니다'; END IF;
  SELECT * INTO r FROM gov.access_request WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '신청 % 이 없습니다', p_request_id; END IF;
  IF r.status <> 'REQUESTED' THEN RAISE EXCEPTION '이미 처리된 신청입니다 (상태 %)', r.status; END IF;
  IF r.requester_id = v_user THEN RAISE EXCEPTION '본인 신청은 승인할 수 없습니다'; END IF;
  IF r.enterprise_id <> v_ent THEN RAISE EXCEPTION '다른 회사 사용자의 신청은 처리할 수 없습니다'; END IF;
  SELECT * INTO d FROM catalog.dataset WHERE dataset_id = r.dataset_id;
  -- 소유자·스튜어드가 비어 있으면 NULL 이 되므로 IS NOT TRUE 로 거부 쪽에 접는다 (재검토 N2)
  IF (v_user = d.owner_user_id OR v_user = d.steward_user_id
      OR EXISTS (SELECT 1 FROM gov.role_assignment ra
                  WHERE ra.user_id = v_user AND ra.enterprise_id = v_ent AND ra.role_id IN ('data_steward', 'admin')
                    AND (ra.valid_until IS NULL OR ra.valid_until >= current_date))) IS NOT TRUE THEN
    RAISE EXCEPTION '% 은 이 데이터셋의 소유자·스튜어드가 아닙니다', v_user;
  END IF;
  v_status := CASE WHEN p_approve THEN 'APPROVED' ELSE 'REJECTED' END;
  UPDATE gov.access_request SET status = v_status, approver_id = v_user, decided_at = now(), decision_note = p_note
   WHERE request_id = p_request_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text)
  VALUES ('UI', CASE WHEN p_approve THEN 'approve' ELSE 'reject' END, r.dataset_id, 'access_request:' || p_request_id, p_note);
  RETURN v_status;
END $$;

-- 대량 적재용 FK 일시 해제 (리뷰 F11) ------------------------------------------
-- 초기 적재·백필: SELECT gov.fk_bulk_begin('ksx.trace_parameter'); COPY ...; SELECT gov.fk_bulk_end('ksx.trace_parameter');
-- begin 은 테이블의 FK 정의를 보관하고 지운다. end 는 NOT VALID 로 다시 건 뒤 하나씩 VALIDATE 한다(쓰기를 막지 않는 잠금).
-- 위반이 있으면 end 가 그 FK 이름과 함께 실패하고 전체가 되돌려진다(FK 는 해제된 채, 보관 정의는 그대로). 위반 행을 고친 뒤 end 를 다시 부른다.
CREATE TABLE gov.fk_bulk_stash (
    table_name       TEXT NOT NULL,
    constraint_name  TEXT NOT NULL,
    definition       TEXT NOT NULL,
    stashed_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (table_name, constraint_name)
);
CREATE OR REPLACE FUNCTION gov.fk_bulk_begin(p_table regclass) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE r record; n int := 0;
BEGIN
  IF p_table::text NOT LIKE 'ksx.%' THEN RAISE EXCEPTION '표준 존(ksx) 테이블만 대상입니다'; END IF;
  FOR r IN SELECT conname, pg_get_constraintdef(oid) AS def FROM pg_constraint WHERE conrelid = p_table AND contype = 'f' LOOP
    INSERT INTO gov.fk_bulk_stash (table_name, constraint_name, definition) VALUES (p_table::text, r.conname, r.def)
      ON CONFLICT (table_name, constraint_name) DO UPDATE SET definition = EXCLUDED.definition, stashed_at = now();
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', p_table, r.conname);
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;
CREATE OR REPLACE FUNCTION gov.fk_bulk_end(p_table regclass) RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN SELECT constraint_name, definition FROM gov.fk_bulk_stash WHERE table_name = p_table::text LOOP
    -- PG16 은 파티션 테이블에 NOT VALID FK 를 못 건다 → 바로 검증하며 건다(파티션마다 검사)
    EXECUTE format('ALTER TABLE %s ADD CONSTRAINT %I %s%s', p_table, r.constraint_name, r.definition,
                   CASE WHEN (SELECT relkind FROM pg_class WHERE oid = p_table) = 'p' THEN '' ELSE ' NOT VALID' END);
    DELETE FROM gov.fk_bulk_stash WHERE table_name = p_table::text AND constraint_name = r.constraint_name;
    n := n + 1;
  END LOOP;
  FOR r IN SELECT conname FROM pg_constraint WHERE conrelid = p_table AND contype = 'f' AND NOT convalidated LOOP
    EXECUTE format('ALTER TABLE %s VALIDATE CONSTRAINT %I', p_table, r.conname);
  END LOOP;
  RETURN n;
END $$;
