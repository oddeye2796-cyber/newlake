-- V0007: 데이터 스튜어드십 CRUD (2차)
--   · 데이터셋 메타(제목·설명·민감도·담당·보존·태그) 수정, 빈 데이터셋 지우기
--   · 필드 한글 이름·온톨로지 속성·개인정보 여부 수정, 필드 매핑 승인·반려 (mapping_review 기록)
--   · 매핑 버전 상태 바꾸기 (검토 → 승인 / 폐기)
--   · 품질 규칙 CRUD, 품질 실행 기록, 위반 처리 상태·담당자
--   · 열린 위험 닫기, 파이프라인 켜기/끄기·담당·주기
-- 쓰기는 SECURITY DEFINER 함수로만. 감사 기록을 남긴다.

ALTER TABLE catalog.dataset_field ADD COLUMN IF NOT EXISTS description VARCHAR(500);
ALTER TABLE catalog.dataset_field ADD COLUMN IF NOT EXISTS is_pii BOOLEAN NOT NULL DEFAULT false;

-- 역할 확인: 이 가운데 하나라도 있으면 통과. 회사 ID 를 돌려준다.
CREATE OR REPLACE FUNCTION gov.require_role(VARIADIC p_roles text[]) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
BEGIN
  IF v_user IS NULL OR v_ent IS NULL THEN RAISE EXCEPTION 'app.user_id 와 app.enterprise_id 가 필요합니다'; END IF;
  IF NOT EXISTS (SELECT 1 FROM gov.role_assignment ra
                  WHERE ra.user_id = v_user AND ra.enterprise_id = v_ent AND (ra.role_id = 'admin' OR ra.role_id = ANY (p_roles))
                    AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)) THEN
    RAISE EXCEPTION '이 작업은 % 역할이 있어야 합니다', array_to_string(p_roles, '·');
  END IF;
  RETURN v_ent;
END $$;

CREATE OR REPLACE FUNCTION gov.dataset_visible(p_dataset_id text, p_ent text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
  SELECT EXISTS (SELECT 1 FROM catalog.dataset WHERE dataset_id = p_dataset_id AND coalesce(nullif(enterprise_id, ''), p_ent) = p_ent)
$$;

-- ── 데이터셋 메타 ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.update_dataset(p_dataset_id text, p_title text, p_description text, p_sensitivity text,
                                              p_pseudonymized boolean, p_retention text, p_owner text, p_steward text, p_tags text[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('data_steward', 'data_engineer');
BEGIN
  IF NOT gov.dataset_visible(p_dataset_id, v_ent) THEN RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id; END IF;
  IF length(btrim(coalesce(p_title, ''))) = 0 THEN RAISE EXCEPTION '제목이 비어 있습니다'; END IF;
  IF p_sensitivity NOT IN ('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'PERSONAL') THEN RAISE EXCEPTION '민감도 % 는 쓸 수 없습니다', p_sensitivity; END IF;
  IF nullif(p_owner, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gov.app_user WHERE user_id = p_owner AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '소유자 % 가 사용자 목록에 없습니다', p_owner;
  END IF;
  IF nullif(p_steward, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gov.app_user WHERE user_id = p_steward AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '스튜어드 % 가 사용자 목록에 없습니다', p_steward;
  END IF;
  UPDATE catalog.dataset
     SET title_ko = btrim(p_title), description = nullif(btrim(coalesce(p_description, '')), ''), sensitivity = p_sensitivity,
         pseudonymized = coalesce(p_pseudonymized, false), retention = nullif(btrim(coalesce(p_retention, '')), '')::interval,
         owner_user_id = nullif(p_owner, ''), steward_user_id = nullif(p_steward, ''),
         tags = coalesce(p_tags, '{}'), updated_at = now()
   WHERE dataset_id = p_dataset_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text)
  VALUES ('UI', 'update_dataset', p_dataset_id, 'catalog.dataset:' || p_dataset_id, p_sensitivity);
END $$;

-- 빈 데이터셋만 (적재 배치·계보·매핑·품질 실행이 없을 때)
CREATE OR REPLACE FUNCTION gov.delete_dataset(p_dataset_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('data_steward', 'data_engineer');
BEGIN
  IF NOT gov.dataset_visible(p_dataset_id, v_ent) THEN RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id; END IF;
  IF EXISTS (SELECT 1 FROM catalog.dataset WHERE dataset_id = p_dataset_id AND zone_id <> 'RAW') THEN
    RAISE EXCEPTION '원천 존 데이터셋만 지울 수 있습니다. 표준·시맨틱·활용 존은 스키마에 묶여 있습니다';
  END IF;
  IF EXISTS (SELECT 1 FROM raw.ingest_batch WHERE dataset_id = p_dataset_id) THEN
    RAISE EXCEPTION '적재 배치가 남아 있습니다. 데이터 넣기 → 적재 기록에서 먼저 지우세요';
  END IF;
  IF EXISTS (SELECT 1 FROM catalog.lineage_edge WHERE from_dataset_id = p_dataset_id OR to_dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM catalog.mapping WHERE source_dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM catalog.quality_run WHERE dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM gov.access_request WHERE dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM gov.access_policy WHERE target_dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM catalog.quality_rule WHERE target_dataset_id = p_dataset_id) THEN
    RAISE EXCEPTION '계보·매핑·품질·접근 기록이 이 데이터셋을 가리키고 있어 지울 수 없습니다';
  END IF;
  DELETE FROM catalog.dataset_field WHERE dataset_id = p_dataset_id;
  DELETE FROM catalog.dataset WHERE dataset_id = p_dataset_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref) VALUES ('UI', 'delete_dataset', p_dataset_id, 'catalog.dataset:' || p_dataset_id);
END $$;

-- ── 필드 ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.update_field(p_dataset_id text, p_field text, p_label text, p_description text, p_is_pii boolean,
                                            p_property_iri text, p_decision text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_role('data_steward', 'ontology_manager');
  v_user text := current_setting('app.user_id', true);
  f catalog.dataset_field;
BEGIN
  IF NOT gov.dataset_visible(p_dataset_id, v_ent) THEN RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id; END IF;
  SELECT * INTO f FROM catalog.dataset_field WHERE dataset_id = p_dataset_id AND field_name = p_field FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '필드 % 가 없습니다', p_field; END IF;
  IF nullif(p_property_iri, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM onto.property WHERE property_iri = p_property_iri) THEN
    RAISE EXCEPTION '온톨로지 속성 % 가 없습니다', p_property_iri;
  END IF;
  IF p_decision IS NOT NULL AND p_decision NOT IN ('ACCEPT', 'REJECT') THEN RAISE EXCEPTION '결정은 ACCEPT 또는 REJECT 입니다'; END IF;
  UPDATE catalog.dataset_field
     SET label_ko = nullif(btrim(coalesce(p_label, '')), ''), description = nullif(btrim(coalesce(p_description, '')), ''),
         is_pii = coalesce(p_is_pii, false),
         maps_to_property_iri = CASE WHEN p_decision = 'REJECT' THEN NULL ELSE nullif(p_property_iri, '') END,
         mapping_method = CASE WHEN nullif(p_property_iri, '') IS DISTINCT FROM f.maps_to_property_iri OR p_decision IS NOT NULL THEN 'human' ELSE f.mapping_method END,
         mapping_confidence = CASE WHEN p_decision = 'ACCEPT' OR nullif(p_property_iri, '') IS DISTINCT FROM f.maps_to_property_iri THEN 1 ELSE f.mapping_confidence END,
         mapping_status = CASE WHEN p_decision = 'ACCEPT' THEN 'APPROVED' WHEN p_decision = 'REJECT' THEN 'REJECTED'
                               WHEN nullif(p_property_iri, '') IS DISTINCT FROM f.maps_to_property_iri THEN 'APPROVED' ELSE f.mapping_status END
   WHERE dataset_id = p_dataset_id AND field_name = p_field;
  IF p_decision IS NOT NULL OR nullif(p_property_iri, '') IS DISTINCT FROM f.maps_to_property_iri THEN
    INSERT INTO catalog.mapping_review (dataset_id, field_name, candidate_property_iri, method, confidence, rationale, decision, decided_by, decided_at)
    VALUES (p_dataset_id, p_field, coalesce(nullif(p_property_iri, ''), f.maps_to_property_iri), 'human', 1,
            CASE WHEN p_decision = 'REJECT' THEN '스튜어드 반려' WHEN p_decision = 'ACCEPT' THEN '스튜어드 승인' ELSE '스튜어드 수정' END,
            CASE WHEN p_decision = 'REJECT' THEN 'REJECT' WHEN p_decision = 'ACCEPT' THEN 'ACCEPT' ELSE 'EDIT' END, v_user, now());
  END IF;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text)
  VALUES ('UI', 'update_field', p_dataset_id, 'catalog.dataset_field:' || p_dataset_id || '.' || p_field, coalesce(p_decision, 'edit'));
END $$;

-- ── 매핑 버전 상태 ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.set_mapping_status(p_mapping_id text, p_status text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_role('data_steward', 'ontology_manager');
  v_user text := current_setting('app.user_id', true);
  m catalog.mapping;
BEGIN
  SELECT * INTO m FROM catalog.mapping WHERE mapping_id = p_mapping_id FOR UPDATE;
  IF NOT FOUND OR NOT gov.dataset_visible(m.source_dataset_id, v_ent) THEN RAISE EXCEPTION '매핑 % 가 없습니다', p_mapping_id; END IF;
  IF p_status NOT IN ('REVIEW', 'APPROVED', 'RETIRED') THEN RAISE EXCEPTION '상태 % 는 쓸 수 없습니다', p_status; END IF;
  IF m.status = p_status THEN RAISE EXCEPTION '이미 % 상태입니다', p_status; END IF;
  UPDATE catalog.mapping SET status = p_status,
         approved_by = CASE WHEN p_status = 'APPROVED' THEN v_user ELSE approved_by END,
         approved_at = CASE WHEN p_status = 'APPROVED' THEN now() ELSE approved_at END
   WHERE mapping_id = p_mapping_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text)
  VALUES ('UI', 'mapping_status', m.source_dataset_id, 'catalog.mapping:' || p_mapping_id, m.status || '→' || p_status);
  RETURN p_status;
END $$;

-- ── 품질 규칙 ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.save_quality_rule(p_rule_id text, p_label text, p_dimension text, p_target_class_iri text, p_target_dataset_id text,
                                                 p_shape_iri text, p_sql_check text, p_severity text, p_threshold numeric, p_enabled boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('quality_engineer', 'data_steward');
BEGIN
  IF p_rule_id !~ '^[A-Za-z0-9][A-Za-z0-9._-]{1,99}$' THEN RAISE EXCEPTION '규칙 ID 는 영문·숫자·.-_ 2~100자여야 합니다'; END IF;
  IF length(btrim(coalesce(p_label, ''))) = 0 THEN RAISE EXCEPTION '규칙 이름이 비어 있습니다'; END IF;
  IF p_dimension NOT IN ('완전성', '유일성', '유효성', '일관성', '정확성', '구조', '값', '관계', '의미') THEN RAISE EXCEPTION '차원 % 는 쓸 수 없습니다', p_dimension; END IF;
  IF p_severity NOT IN ('Info', 'Warning', 'Violation') THEN RAISE EXCEPTION '심각도 % 는 쓸 수 없습니다', p_severity; END IF;
  IF nullif(p_target_class_iri, '') IS NULL AND nullif(p_target_dataset_id, '') IS NULL THEN RAISE EXCEPTION '대상 클래스나 데이터셋 중 하나는 있어야 합니다'; END IF;
  IF nullif(p_target_class_iri, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_target_class_iri) THEN
    RAISE EXCEPTION '클래스 % 가 없습니다', p_target_class_iri;
  END IF;
  IF nullif(p_target_dataset_id, '') IS NOT NULL AND NOT gov.dataset_visible(p_target_dataset_id, v_ent) THEN
    RAISE EXCEPTION '데이터셋 % 가 없습니다', p_target_dataset_id;
  END IF;
  IF nullif(p_sql_check, '') IS NOT NULL AND p_sql_check !~* '^\s*select\M' THEN RAISE EXCEPTION '검사식은 SELECT 한 문장이어야 합니다'; END IF;
  IF p_threshold IS NOT NULL AND (p_threshold < 0 OR p_threshold > 100) THEN RAISE EXCEPTION '기준 적합률은 0~100 사이여야 합니다'; END IF;
  INSERT INTO catalog.quality_rule (rule_id, label_ko, dimension, target_class_iri, target_dataset_id, shape_iri, sql_check, severity, threshold, enabled)
  VALUES (p_rule_id, btrim(p_label), p_dimension, nullif(p_target_class_iri, ''), nullif(p_target_dataset_id, ''), nullif(p_shape_iri, ''),
          nullif(btrim(coalesce(p_sql_check, '')), ''), p_severity, p_threshold, coalesce(p_enabled, true))
  ON CONFLICT (rule_id) DO UPDATE
     SET label_ko = EXCLUDED.label_ko, dimension = EXCLUDED.dimension, target_class_iri = EXCLUDED.target_class_iri,
         target_dataset_id = EXCLUDED.target_dataset_id, shape_iri = EXCLUDED.shape_iri, sql_check = EXCLUDED.sql_check,
         severity = EXCLUDED.severity, threshold = EXCLUDED.threshold, enabled = EXCLUDED.enabled;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text)
  VALUES ('UI', 'save_quality_rule', nullif(p_target_dataset_id, ''), 'catalog.quality_rule:' || p_rule_id, p_severity || CASE WHEN coalesce(p_enabled, true) THEN '' ELSE ' (꺼짐)' END);
  RETURN p_rule_id;
END $$;

CREATE OR REPLACE FUNCTION gov.delete_quality_rule(p_rule_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('quality_engineer', 'data_steward'); n int;
BEGIN
  IF EXISTS (SELECT 1 FROM catalog.quality_violation WHERE rule_id = p_rule_id) THEN
    RAISE EXCEPTION '규칙 % 의 위반 기록이 있어 지울 수 없습니다. 대신 끄세요', p_rule_id;
  END IF;
  DELETE FROM catalog.quality_rule WHERE rule_id = p_rule_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN RAISE EXCEPTION '규칙 % 가 없습니다', p_rule_id; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref) VALUES ('UI', 'delete_quality_rule', 'catalog.quality_rule:' || p_rule_id);
END $$;

-- 품질 검사 결과 기록. 검사식 실행은 API 가 lake_agent(읽기 전용·RLS)로 하고, 결과만 여기로 넘긴다.
-- p_violations: [{focus_node, result_path, message}]
CREATE OR REPLACE FUNCTION gov.record_quality_run(p_rule_id text, p_dataset_id text, p_focus_count bigint, p_violations jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_role('quality_engineer', 'data_steward');
  r catalog.quality_rule;
  v_run uuid;
  v_job uuid;
  n_v int := coalesce(jsonb_array_length(p_violations), 0);
  v_rate numeric;
BEGIN
  SELECT * INTO r FROM catalog.quality_rule WHERE rule_id = p_rule_id;
  IF NOT FOUND THEN RAISE EXCEPTION '규칙 % 가 없습니다', p_rule_id; END IF;
  IF p_dataset_id IS NOT NULL AND NOT gov.dataset_visible(p_dataset_id, v_ent) THEN RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id; END IF;
  INSERT INTO catalog.job_run (pipeline_id, status, rows_in, rows_out, rows_rejected, ended_at, enterprise_id, code_version)
  VALUES ('p-console-std', 'SUCCESS', p_focus_count, p_focus_count - least(n_v, coalesce(p_focus_count, 0)), n_v, now(), v_ent, 'console-quality')
  RETURNING run_id INTO v_job;
  INSERT INTO catalog.quality_run (job_run_id, dataset_id, focus_count, violation_count)
  VALUES (v_job, p_dataset_id, p_focus_count, n_v) RETURNING quality_run_id, conformance_rate INTO v_run, v_rate;
  INSERT INTO catalog.quality_violation (quality_run_id, rule_id, focus_node, result_path, message, severity)
  SELECT v_run, p_rule_id, left(coalesce(x ->> 'focus_node', '?'), 300), left(x ->> 'result_path', 200),
         left(coalesce(x ->> 'message', r.label_ko), 500), r.severity
    FROM jsonb_array_elements(p_violations) x;
  IF p_dataset_id IS NOT NULL THEN
    UPDATE catalog.dataset
       SET quality_score = v_rate,
           quality_status = CASE WHEN v_rate IS NULL THEN 'UNKNOWN' WHEN r.threshold IS NOT NULL AND v_rate < r.threshold THEN 'FAIL'
                                 WHEN n_v > 0 THEN 'WARN' ELSE 'PASS' END,
           updated_at = now()
     WHERE dataset_id = p_dataset_id;
  END IF;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, row_count, result)
  VALUES ('UI', 'run_quality_rule', p_dataset_id, 'catalog.quality_rule:' || p_rule_id, n_v, 'OK');
  RETURN jsonb_build_object('quality_run_id', v_run, 'focus_count', p_focus_count, 'violation_count', n_v, 'conformance_rate', v_rate);
END $$;

CREATE OR REPLACE FUNCTION gov.update_violation(p_violation_id bigint, p_status text, p_assignee text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('quality_engineer', 'data_steward'); n int;
BEGIN
  IF p_status NOT IN ('OPEN', 'ACK', 'FIXED', 'WAIVED') THEN RAISE EXCEPTION '상태 % 는 쓸 수 없습니다', p_status; END IF;
  IF nullif(p_assignee, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gov.app_user WHERE user_id = p_assignee AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '담당자 % 가 사용자 목록에 없습니다', p_assignee;
  END IF;
  UPDATE catalog.quality_violation SET status = p_status, assignee_user_id = nullif(p_assignee, ''),
         resolved_at = CASE WHEN p_status IN ('FIXED', 'WAIVED') THEN now() ELSE NULL END
   WHERE violation_id = p_violation_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN RAISE EXCEPTION '위반 % 가 없습니다', p_violation_id; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'update_violation', 'catalog.quality_violation:' || p_violation_id, p_status || coalesce(' → ' || p_assignee, ''));
END $$;

-- ── 위험·파이프라인 ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.set_risk_status(p_event_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('production_manager', 'quality_engineer', 'data_steward'); r sem.risk_event;
BEGIN
  IF p_status NOT IN ('OPEN', 'CLOSED', 'SUPPRESSED') THEN RAISE EXCEPTION '상태 % 는 쓸 수 없습니다', p_status; END IF;
  SELECT * INTO r FROM sem.risk_event WHERE event_id = p_event_id FOR UPDATE;
  IF NOT FOUND OR r.enterprise_id <> v_ent THEN RAISE EXCEPTION '위험 % 가 없습니다', p_event_id; END IF;
  IF NOT gov.scope_ok(r.enterprise_id, r.site_id, r.plant_id) THEN RAISE EXCEPTION '이 위험은 내 사업장·공장 범위 밖입니다'; END IF;
  UPDATE sem.risk_event SET status = p_status WHERE event_id = p_event_id;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'risk_status', 'sem.risk_event:' || p_event_id, r.status || '→' || p_status);
END $$;

CREATE OR REPLACE FUNCTION gov.update_pipeline(p_pipeline_id text, p_enabled boolean, p_owner text, p_schedule_cron text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('data_engineer'); n int;
BEGIN
  IF nullif(p_owner, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM gov.app_user WHERE user_id = p_owner AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '담당자 % 가 사용자 목록에 없습니다', p_owner;
  END IF;
  IF nullif(p_schedule_cron, '') IS NOT NULL AND p_schedule_cron !~ '^(\S+\s+){4}\S+$' THEN RAISE EXCEPTION '주기는 cron 다섯 칸이어야 합니다 (예: */10 * * * *)'; END IF;
  UPDATE catalog.pipeline SET enabled = coalesce(p_enabled, enabled), owner_user_id = nullif(p_owner, ''), schedule_cron = nullif(p_schedule_cron, '')
   WHERE pipeline_id = p_pipeline_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 0 THEN RAISE EXCEPTION '파이프라인 % 가 없습니다', p_pipeline_id; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'update_pipeline', 'catalog.pipeline:' || p_pipeline_id, CASE WHEN coalesce(p_enabled, true) THEN 'on' ELSE 'off' END || coalesce(' ' || p_schedule_cron, ''));
END $$;

REVOKE ALL ON FUNCTION gov.require_role(text[]), gov.dataset_visible(text, text),
  gov.update_dataset(text, text, text, text, boolean, text, text, text, text[]), gov.delete_dataset(text),
  gov.update_field(text, text, text, text, boolean, text, text), gov.set_mapping_status(text, text),
  gov.save_quality_rule(text, text, text, text, text, text, text, text, numeric, boolean), gov.delete_quality_rule(text),
  gov.record_quality_run(text, text, bigint, jsonb), gov.update_violation(bigint, text, text),
  gov.set_risk_status(uuid, text), gov.update_pipeline(text, boolean, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.require_role(text[]), gov.dataset_visible(text, text),
  gov.update_dataset(text, text, text, text, boolean, text, text, text, text[]), gov.delete_dataset(text),
  gov.update_field(text, text, text, text, boolean, text, text), gov.set_mapping_status(text, text),
  gov.save_quality_rule(text, text, text, text, text, text, text, text, numeric, boolean), gov.delete_quality_rule(text),
  gov.record_quality_run(text, text, bigint, jsonb), gov.update_violation(bigint, text, text),
  gov.set_risk_status(uuid, text), gov.update_pipeline(text, boolean, text, text) TO lake_app;
