-- V0006: 권한·운영 CRUD (1차)
--   · 사용자, 역할 배정·범위, 접근 정책, 조치 정책: 관리자(admin)만 쓰기
--   · 접근 요청 만들기·취소: 누구나 (본인 것만 취소)
--   · 적재 배치 지우기: 데이터 넣기 역할
-- 모든 쓰기는 SECURITY DEFINER 함수로만 하고, 감사 기록을 남긴다. 역할 종류(gov.role)와 감사 기록은 그대로 읽기 전용.

ALTER TABLE gov.access_request DROP CONSTRAINT IF EXISTS access_request_status_check;
ALTER TABLE gov.access_request ADD CONSTRAINT access_request_status_check
  CHECK (status IN ('REQUESTED', 'APPROVED', 'REJECTED', 'EXPIRED', 'REVOKED', 'CANCELLED'));

CREATE OR REPLACE FUNCTION gov.require_admin() RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
BEGIN
  IF v_user IS NULL OR v_ent IS NULL THEN RAISE EXCEPTION 'app.user_id 와 app.enterprise_id 가 필요합니다'; END IF;
  IF NOT EXISTS (SELECT 1 FROM gov.role_assignment ra
                  WHERE ra.user_id = v_user AND ra.enterprise_id = v_ent AND ra.role_id = 'admin'
                    AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)) THEN
    RAISE EXCEPTION '플랫폼 관리자(admin)만 할 수 있습니다';
  END IF;
  RETURN v_ent;
END $$;

-- ── 사용자 ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.admin_users()
RETURNS TABLE (user_id text, display_name text, email text, personnel_id text, status text, created_at timestamptz, roles text[])
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_admin();
BEGIN
  RETURN QUERY
  SELECT u.user_id::text, u.display_name::text, u.email::text, u.personnel_id::text, u.status::text, u.created_at,
         coalesce(array_agg(DISTINCT ra.role_id::text) FILTER (WHERE ra.role_id IS NOT NULL), '{}')
    FROM gov.app_user u
    LEFT JOIN gov.role_assignment ra ON ra.user_id = u.user_id AND ra.enterprise_id = u.enterprise_id
         AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)
   WHERE u.enterprise_id = v_ent
   GROUP BY u.user_id, u.display_name, u.email, u.personnel_id, u.status, u.created_at
   ORDER BY u.user_id;
END $$;

CREATE OR REPLACE FUNCTION gov.save_user(p_user_id text, p_display_name text, p_email text DEFAULT NULL,
                                         p_personnel_id text DEFAULT NULL, p_status text DEFAULT 'ACTIVE')
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_admin();
  v_me   text := current_setting('app.user_id', true);
BEGIN
  IF p_user_id !~ '^[a-z0-9][a-z0-9._-]{1,49}$' THEN RAISE EXCEPTION '사용자 ID 는 영문 소문자·숫자·.-_ 2~50자여야 합니다'; END IF;
  IF p_status NOT IN ('ACTIVE', 'LOCKED', 'RETIRED') THEN RAISE EXCEPTION '상태 % 는 쓸 수 없습니다', p_status; END IF;
  IF p_user_id = v_me AND p_status <> 'ACTIVE' THEN RAISE EXCEPTION '내 계정은 잠그거나 퇴직 처리할 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM gov.app_user WHERE user_id = p_user_id AND enterprise_id <> v_ent) THEN
    RAISE EXCEPTION '사용자 ID % 는 다른 회사에서 쓰고 있습니다', p_user_id;
  END IF;
  INSERT INTO gov.app_user (user_id, display_name, email, personnel_id, enterprise_id, status)
  VALUES (p_user_id, p_display_name, nullif(p_email, ''), nullif(p_personnel_id, ''), v_ent, p_status)
  ON CONFLICT (user_id) DO UPDATE
     SET display_name = EXCLUDED.display_name, email = EXCLUDED.email, personnel_id = EXCLUDED.personnel_id, status = EXCLUDED.status;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'save_user', 'gov.app_user:' || p_user_id, p_status);
  RETURN p_user_id;
END $$;

-- ── 역할 배정 ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.grant_role(p_user_id text, p_role_id text, p_site_id text DEFAULT NULL,
                                          p_plant_id text DEFAULT NULL, p_valid_until date DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent text := gov.require_admin();
  v_me  text := current_setting('app.user_id', true);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM gov.app_user WHERE user_id = p_user_id AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '사용자 % 가 없습니다', p_user_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM gov.role WHERE role_id = p_role_id) THEN RAISE EXCEPTION '역할 % 가 없습니다', p_role_id; END IF;
  IF p_plant_id IS NOT NULL AND p_site_id IS NULL THEN RAISE EXCEPTION '공장을 정하려면 사업장도 정해야 합니다'; END IF;
  IF p_site_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ksx.site WHERE enterprise_id = v_ent AND site_id = p_site_id) THEN
    RAISE EXCEPTION '사업장 % 가 없습니다', p_site_id;
  END IF;
  IF p_plant_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ksx.plant WHERE enterprise_id = v_ent AND site_id = p_site_id AND plant_id = p_plant_id) THEN
    RAISE EXCEPTION '공장 % 가 없습니다', p_plant_id;
  END IF;
  INSERT INTO gov.role_assignment (user_id, role_id, enterprise_id, site_id, plant_id, valid_until, granted_by)
  VALUES (p_user_id, p_role_id, v_ent, nullif(p_site_id, ''), nullif(p_plant_id, ''), p_valid_until, v_me)
  ON CONFLICT (user_id, role_id, enterprise_id, site_id, plant_id) DO UPDATE
     SET valid_until = EXCLUDED.valid_until, granted_by = EXCLUDED.granted_by, granted_at = now();
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'grant_role', 'gov.role_assignment:' || p_user_id || '/' || p_role_id,
          coalesce(p_site_id, '*') || '/' || coalesce(p_plant_id, '*') || coalesce(' ~' || p_valid_until, ''));
END $$;

CREATE OR REPLACE FUNCTION gov.revoke_role(p_user_id text, p_role_id text, p_site_id text DEFAULT NULL, p_plant_id text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent text := gov.require_admin();
  v_me  text := current_setting('app.user_id', true);
  n int;
BEGIN
  IF p_user_id = v_me AND p_role_id = 'admin' THEN RAISE EXCEPTION '내 admin 역할은 스스로 뺄 수 없습니다'; END IF;
  DELETE FROM gov.role_assignment
   WHERE user_id = p_user_id AND role_id = p_role_id AND enterprise_id = v_ent
     AND site_id IS NOT DISTINCT FROM nullif(p_site_id, '') AND plant_id IS NOT DISTINCT FROM nullif(p_plant_id, '');
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN RAISE EXCEPTION '그런 역할 배정이 없습니다'; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'revoke_role', 'gov.role_assignment:' || p_user_id || '/' || p_role_id,
          coalesce(p_site_id, '*') || '/' || coalesce(p_plant_id, '*'));
END $$;

-- ── 접근 정책 ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.save_access_policy(p_policy_id text, p_role_id text, p_target_class_iri text, p_target_dataset_id text,
                                                  p_max_sensitivity text, p_actions text[], p_requires_approval boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_admin();
BEGIN
  IF p_policy_id !~ '^[A-Za-z0-9][A-Za-z0-9._-]{1,99}$' THEN RAISE EXCEPTION '정책 ID 는 영문·숫자·.-_ 2~100자여야 합니다'; END IF;
  IF NOT EXISTS (SELECT 1 FROM gov.role WHERE role_id = p_role_id) THEN RAISE EXCEPTION '역할 % 가 없습니다', p_role_id; END IF;
  IF p_max_sensitivity NOT IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'PERSONAL') THEN RAISE EXCEPTION '민감도 % 는 쓸 수 없습니다', p_max_sensitivity; END IF;
  IF nullif(p_target_class_iri, '') IS NULL AND nullif(p_target_dataset_id, '') IS NULL THEN RAISE EXCEPTION '대상 클래스나 데이터셋 중 하나는 있어야 합니다'; END IF;
  IF nullif(p_target_class_iri, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_target_class_iri) THEN
    RAISE EXCEPTION '클래스 % 가 없습니다', p_target_class_iri;
  END IF;
  IF nullif(p_target_dataset_id, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM catalog.dataset WHERE dataset_id = p_target_dataset_id AND coalesce(nullif(enterprise_id, ''), v_ent) = v_ent) THEN
    RAISE EXCEPTION '데이터셋 % 가 없습니다', p_target_dataset_id;
  END IF;
  IF p_actions IS NULL OR cardinality(p_actions) = 0 OR EXISTS (SELECT 1 FROM unnest(p_actions) a WHERE a NOT IN ('read', 'query', 'download', 'export')) THEN
    RAISE EXCEPTION '허용 행위는 read·query·download·export 가운데 하나 이상이어야 합니다';
  END IF;
  INSERT INTO gov.access_policy (policy_id, role_id, target_class_iri, target_dataset_id, max_sensitivity, actions, requires_approval)
  VALUES (p_policy_id, p_role_id, nullif(p_target_class_iri, ''), nullif(p_target_dataset_id, ''), p_max_sensitivity, p_actions, coalesce(p_requires_approval, false))
  ON CONFLICT (policy_id) DO UPDATE
     SET role_id = EXCLUDED.role_id, target_class_iri = EXCLUDED.target_class_iri, target_dataset_id = EXCLUDED.target_dataset_id,
         max_sensitivity = EXCLUDED.max_sensitivity, actions = EXCLUDED.actions, requires_approval = EXCLUDED.requires_approval;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'save_access_policy', 'gov.access_policy:' || p_policy_id, p_role_id || ' ' || array_to_string(p_actions, ','));
  RETURN p_policy_id;
END $$;

CREATE OR REPLACE FUNCTION gov.delete_access_policy(p_policy_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_admin(); n int;
BEGIN
  DELETE FROM gov.access_policy WHERE policy_id = p_policy_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN RAISE EXCEPTION '정책 % 가 없습니다', p_policy_id; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref) VALUES ('UI', 'delete_access_policy', 'gov.access_policy:' || p_policy_id);
END $$;

-- ── 조치 정책 ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.save_action_policy(p_policy_id text, p_trigger_class_iri text, p_condition jsonb, p_action_iri text,
                                                  p_mode text, p_approver_role_id text, p_notify_role_ids text[],
                                                  p_suppress_minutes int, p_enabled boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_admin();
BEGIN
  IF p_policy_id !~ '^[A-Za-z0-9][A-Za-z0-9._-]{1,99}$' THEN RAISE EXCEPTION '정책 ID 는 영문·숫자·.-_ 2~100자여야 합니다'; END IF;
  IF p_mode NOT IN ('auto', 'approval', 'notify') THEN RAISE EXCEPTION '방식 % 는 쓸 수 없습니다', p_mode; END IF;
  IF p_mode = 'approval' AND nullif(p_approver_role_id, '') IS NULL THEN RAISE EXCEPTION '승인 방식이면 승인자 역할이 필요합니다'; END IF;
  IF NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_trigger_class_iri) THEN RAISE EXCEPTION '클래스 % 가 없습니다', p_trigger_class_iri; END IF;
  IF NOT EXISTS (SELECT 1 FROM onto.action WHERE action_iri = p_action_iri) THEN RAISE EXCEPTION '조치 % 가 없습니다', p_action_iri; END IF;
  IF nullif(p_approver_role_id, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gov.role WHERE role_id = p_approver_role_id) THEN
    RAISE EXCEPTION '역할 % 가 없습니다', p_approver_role_id;
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(coalesce(p_notify_role_ids, '{}')) r WHERE NOT EXISTS (SELECT 1 FROM gov.role WHERE role_id = r)) THEN
    RAISE EXCEPTION '알림 역할에 없는 역할이 있습니다';
  END IF;
  IF p_condition IS NULL OR jsonb_typeof(p_condition) <> 'object' THEN RAISE EXCEPTION '조건은 JSON 객체여야 합니다'; END IF;
  INSERT INTO gov.action_policy (policy_id, trigger_class_iri, condition, action_iri, mode, approver_role_id, notify_role_ids, suppress_window, enterprise_id, enabled)
  VALUES (p_policy_id, p_trigger_class_iri, p_condition, p_action_iri, p_mode, nullif(p_approver_role_id, ''), coalesce(p_notify_role_ids, '{}'),
          make_interval(mins => greatest(coalesce(p_suppress_minutes, 240), 0)), v_ent, coalesce(p_enabled, true))
  ON CONFLICT (policy_id) DO UPDATE
     SET trigger_class_iri = EXCLUDED.trigger_class_iri, condition = EXCLUDED.condition, action_iri = EXCLUDED.action_iri, mode = EXCLUDED.mode,
         approver_role_id = EXCLUDED.approver_role_id, notify_role_ids = EXCLUDED.notify_role_ids, suppress_window = EXCLUDED.suppress_window,
         enabled = EXCLUDED.enabled;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'save_action_policy', 'gov.action_policy:' || p_policy_id, p_mode || CASE WHEN coalesce(p_enabled, true) THEN '' ELSE ' (꺼짐)' END);
  RETURN p_policy_id;
END $$;

CREATE OR REPLACE FUNCTION gov.delete_action_policy(p_policy_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_admin(); n int;
BEGIN
  IF EXISTS (SELECT 1 FROM gov.action_execution WHERE policy_id = p_policy_id) THEN
    RAISE EXCEPTION '정책 % 로 실행된 조치 기록이 있어 지울 수 없습니다. 대신 끄세요', p_policy_id;
  END IF;
  DELETE FROM gov.action_policy WHERE policy_id = p_policy_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN RAISE EXCEPTION '정책 % 가 없습니다', p_policy_id; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref) VALUES ('UI', 'delete_action_policy', 'gov.action_policy:' || p_policy_id);
END $$;

-- ── 접근 요청 (누구나) ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.create_access_request(p_dataset_id text, p_purpose text, p_actions text[], p_from date, p_to date)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
  v_id   uuid;
BEGIN
  IF v_user IS NULL OR v_ent IS NULL THEN RAISE EXCEPTION 'app.user_id 와 app.enterprise_id 가 필요합니다'; END IF;
  IF NOT EXISTS (SELECT 1 FROM catalog.dataset WHERE dataset_id = p_dataset_id AND coalesce(nullif(enterprise_id, ''), v_ent) = v_ent) THEN
    RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id;
  END IF;
  IF length(btrim(coalesce(p_purpose, ''))) < 5 THEN RAISE EXCEPTION '목적을 5자 이상 적어 주세요'; END IF;
  IF p_actions IS NULL OR cardinality(p_actions) = 0 OR EXISTS (SELECT 1 FROM unnest(p_actions) a WHERE a NOT IN ('read', 'query', 'download', 'export')) THEN
    RAISE EXCEPTION '요청 행위는 read·query·download·export 가운데 하나 이상이어야 합니다';
  END IF;
  IF p_from IS NULL OR p_to IS NULL OR p_to < p_from THEN RAISE EXCEPTION '기간이 올바르지 않습니다'; END IF;
  IF EXISTS (SELECT 1 FROM gov.access_request WHERE requester_id = v_user AND dataset_id = p_dataset_id AND status = 'REQUESTED') THEN
    RAISE EXCEPTION '이 데이터셋에 이미 승인 대기 중인 요청이 있습니다';
  END IF;
  INSERT INTO gov.access_request (requester_id, dataset_id, purpose, requested_actions, period_from, period_to, enterprise_id)
  VALUES (v_user, p_dataset_id, btrim(p_purpose), p_actions, p_from, p_to, v_ent) RETURNING request_id INTO v_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text)
  VALUES ('UI', 'request_access', p_dataset_id, 'access_request:' || v_id, btrim(p_purpose));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION gov.cancel_access_request(p_request_id uuid)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  r gov.access_request;
BEGIN
  SELECT * INTO r FROM gov.access_request WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND OR r.requester_id <> v_user THEN RAISE EXCEPTION '내가 보낸 요청이 아닙니다'; END IF;
  IF r.status NOT IN ('REQUESTED', 'APPROVED') THEN RAISE EXCEPTION '이미 끝난 요청입니다 (상태 %)', r.status; END IF;
  UPDATE gov.access_request SET status = 'CANCELLED', decided_at = now() WHERE request_id = p_request_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref)
  VALUES ('UI', 'cancel_access', r.dataset_id, 'access_request:' || p_request_id);
  RETURN 'CANCELLED';
END $$;

CREATE OR REPLACE FUNCTION gov.my_access_requests()
RETURNS TABLE (request_id uuid, dataset_id text, dataset_title text, purpose text, requested_actions text[], period_from date, period_to date,
               status text, approver_id text, decided_at timestamptz, decision_note text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
  SELECT a.request_id, a.dataset_id::text, d.title_ko::text, a.purpose::text, a.requested_actions, a.period_from, a.period_to,
         a.status::text, a.approver_id::text, a.decided_at, a.decision_note::text, a.created_at
    FROM gov.access_request a LEFT JOIN catalog.dataset d ON d.dataset_id = a.dataset_id
   WHERE a.requester_id = nullif(current_setting('app.user_id', true), '')
   ORDER BY (a.status = 'REQUESTED') DESC, a.created_at DESC LIMIT 100
$$;

-- ── 적재 배치 지우기 (원천 존만) ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.delete_batch(p_batch_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent text := gov.require_ingest_role();
  b raw.ingest_batch;
  n_rec bigint;
  v_more int;
BEGIN
  SELECT * INTO b FROM raw.ingest_batch WHERE batch_id = p_batch_id FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  DELETE FROM raw.landing_file WHERE batch_id = p_batch_id;
  DELETE FROM raw.landing_record WHERE batch_id = p_batch_id;
  GET DIAGNOSTICS n_rec = ROW_COUNT;
  DELETE FROM raw.ingest_batch WHERE batch_id = p_batch_id;
  UPDATE catalog.dataset SET record_count = greatest(coalesce(record_count, 0) - b.record_count, 0), updated_at = now() WHERE dataset_id = b.dataset_id;
  SELECT count(*) INTO v_more FROM raw.ingest_batch WHERE dataset_id = b.dataset_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, row_count, result)
  VALUES ('UI', 'delete_batch', b.dataset_id, 'raw.ingest_batch:' || p_batch_id, n_rec, 'OK');
  RETURN jsonb_build_object('batch_id', p_batch_id, 'records', n_rec, 'std_table', b.std_table, 'remaining_batches', v_more);
END $$;

GRANT SELECT ON gov.app_user TO lake_app;
REVOKE ALL ON FUNCTION gov.require_admin(), gov.admin_users(), gov.save_user(text, text, text, text, text),
  gov.grant_role(text, text, text, text, date), gov.revoke_role(text, text, text, text),
  gov.save_access_policy(text, text, text, text, text, text[], boolean), gov.delete_access_policy(text),
  gov.save_action_policy(text, text, jsonb, text, text, text, text[], int, boolean), gov.delete_action_policy(text),
  gov.create_access_request(text, text, text[], date, date), gov.cancel_access_request(uuid), gov.my_access_requests(),
  gov.delete_batch(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.require_admin(), gov.admin_users(), gov.save_user(text, text, text, text, text),
  gov.grant_role(text, text, text, text, date), gov.revoke_role(text, text, text, text),
  gov.save_access_policy(text, text, text, text, text, text[], boolean), gov.delete_access_policy(text),
  gov.save_action_policy(text, text, jsonb, text, text, text, text[], int, boolean), gov.delete_action_policy(text),
  gov.create_access_request(text, text, text[], date, date), gov.cancel_access_request(uuid), gov.my_access_requests(),
  gov.delete_batch(uuid) TO lake_app;
