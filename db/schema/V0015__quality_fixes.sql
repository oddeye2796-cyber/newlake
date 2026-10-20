-- =============================================================================
-- V0015 품질 검증 바로잡기 (품질 매뉴얼 작성 중 찾은 세 가지)
--   1) 데이터셋 품질 점수: 마지막에 돈 규칙 하나로 덮어쓰지 않고, 걸린 켜진 규칙들의 최신 실행을 종합한다
--      (점수 = 가장 낮은 규칙 적합률, 상태 = 하나라도 기준 미달이면 FAIL · 위반이 있으면 WARN · 아니면 PASS).
--   2) 위반 중복: 다시 실행해도 같은 행(규칙·데이터셋·대상·속성)은 열린 위반 하나로 이어 간다.
--      이번 실행에서 사라진 열린 위반은 자동 해결(FIXED), 예외 처리(WAIVED)한 행은 다시 열지 않는다.
--   3) 시맨틱 존 게이트: 시맨틱 존으로 가는 파이프라인의 원천 데이터셋이 품질 부적합(FAIL)이면
--      그 파이프라인 실행을 시작(job_run RUNNING 등록)할 수 없다.
-- =============================================================================

-- ── 1) 데이터셋 품질 종합 ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.refresh_dataset_quality(p_dataset_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_score numeric; v_status text;
BEGIN
  WITH latest AS (
    SELECT DISTINCT ON (q.rule_id) q.rule_id, q.conformance_rate, q.violation_count, r.threshold
      FROM catalog.quality_run q JOIN catalog.quality_rule r ON r.rule_id = q.rule_id
     WHERE q.dataset_id = p_dataset_id AND r.enabled
     ORDER BY q.rule_id, q.executed_at DESC, q.quality_run_id)
  SELECT min(conformance_rate),
         CASE WHEN count(*) = 0 THEN NULL
              WHEN bool_or(threshold IS NOT NULL AND conformance_rate < threshold) THEN 'FAIL'
              WHEN bool_or(violation_count > 0) THEN 'WARN' ELSE 'PASS' END
    INTO v_score, v_status FROM latest;
  IF v_status IS NULL THEN
    -- 규칙 실행 기록이 없으면(또는 규칙을 다 껐으면) 콘솔 밖(배치 SHACL 등)이 남긴 값을 건드리지 않는다
    RETURN;
  END IF;
  UPDATE catalog.dataset SET quality_score = v_score, quality_status = v_status, updated_at = now()
   WHERE dataset_id = p_dataset_id AND (quality_score IS DISTINCT FROM v_score OR quality_status IS DISTINCT FROM v_status);
END $$;

-- 규칙을 끄거나 기준을 바꾸면 그 규칙이 돈 데이터셋들을 다시 종합한다
CREATE OR REPLACE FUNCTION gov.quality_rule_changed() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE d text;
BEGIN
  FOR d IN SELECT DISTINCT dataset_id FROM catalog.quality_run WHERE rule_id = NEW.rule_id LOOP
    PERFORM gov.refresh_dataset_quality(d);
  END LOOP;
  RETURN NULL;
END $$;
DROP TRIGGER IF EXISTS tr_quality_rule_changed ON catalog.quality_rule;
CREATE TRIGGER tr_quality_rule_changed AFTER UPDATE OF enabled, threshold ON catalog.quality_rule
  FOR EACH ROW WHEN (OLD.enabled IS DISTINCT FROM NEW.enabled OR OLD.threshold IS DISTINCT FROM NEW.threshold)
  EXECUTE FUNCTION gov.quality_rule_changed();

-- ── 2) 실행 기록 + 위반 이어 가기 ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS ix_violation_rule_focus ON catalog.quality_violation (rule_id, focus_node);

-- 검사 결과 JSON → (대상, 속성, 설명) 한 줄씩. 같은 대상·속성이 여러 번 나오면 하나로
CREATE OR REPLACE FUNCTION gov.quality_findings(p_violations jsonb, p_default_msg text)
RETURNS TABLE (focus_node text, result_path text, message text) LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $$
  SELECT DISTINCT ON (fn, rp) fn, rp, msg FROM (
    SELECT left(coalesce(x ->> 'focus_node', '?'), 300) AS fn, left(x ->> 'result_path', 200) AS rp,
           left(coalesce(x ->> 'message', p_default_msg), 500) AS msg
      FROM jsonb_array_elements(coalesce(p_violations, '[]'::jsonb)) x) f
   ORDER BY fn, rp
$$;

DROP FUNCTION IF EXISTS gov.record_quality_run(text, text, bigint, jsonb);
CREATE FUNCTION gov.record_quality_run(p_rule_id text, p_dataset_id text, p_focus_count bigint, p_violations jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_role('quality_engineer', 'data_steward');
  r catalog.quality_rule;
  v_run uuid;
  v_job uuid;
  n_v int := coalesce(jsonb_array_length(p_violations), 0);
  v_rate numeric;
  n_new int; n_kept int; n_auto int; n_waived int;
BEGIN
  SELECT * INTO r FROM catalog.quality_rule WHERE rule_id = p_rule_id;
  IF NOT FOUND THEN RAISE EXCEPTION '규칙 % 가 없습니다', p_rule_id; END IF;
  IF p_dataset_id IS NOT NULL AND NOT gov.dataset_visible(p_dataset_id, v_ent) THEN RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id; END IF;
  INSERT INTO catalog.job_run (pipeline_id, status, rows_in, rows_out, rows_rejected, ended_at, enterprise_id, code_version)
  VALUES ('p-console-std', 'SUCCESS', p_focus_count, p_focus_count - least(n_v, coalesce(p_focus_count, 0)), n_v, now(), v_ent, 'console-quality')
  RETURNING run_id INTO v_job;
  INSERT INTO catalog.quality_run (job_run_id, dataset_id, focus_count, violation_count, rule_id)
  VALUES (v_job, p_dataset_id, p_focus_count, n_v, p_rule_id) RETURNING quality_run_id, conformance_rate INTO v_run, v_rate;

  -- 지난 위반: 같은 규칙·같은 데이터셋, 아직 열린(미처리·확인함) 것과 예외 처리한 것
  -- 아직 열린 위반이 또 나오면 이번 실행으로 옮긴다 (상태·담당 유지)
  UPDATE catalog.quality_violation v SET quality_run_id = v_run, message = f.message, severity = r.severity
    FROM catalog.quality_run q, gov.quality_findings(p_violations, r.label_ko) f
   WHERE q.quality_run_id = v.quality_run_id AND q.dataset_id = p_dataset_id AND q.quality_run_id <> v_run
     AND v.rule_id = p_rule_id AND v.status IN ('OPEN', 'ACK')
     AND f.focus_node = v.focus_node AND f.result_path IS NOT DISTINCT FROM v.result_path;
  GET DIAGNOSTICS n_kept = ROW_COUNT;

  -- 이번에 안 나온 열린 위반은 자동 해결
  UPDATE catalog.quality_violation v SET status = 'FIXED', resolved_at = now()
    FROM catalog.quality_run q
   WHERE q.quality_run_id = v.quality_run_id AND q.dataset_id = p_dataset_id AND q.quality_run_id <> v_run
     AND v.rule_id = p_rule_id AND v.status IN ('OPEN', 'ACK');
  GET DIAGNOSTICS n_auto = ROW_COUNT;

  -- 새로 나온 것만 새 위반으로. 예외 처리한 행은 다시 열지 않는다
  WITH known AS (
    SELECT v.focus_node, v.result_path, v.status FROM catalog.quality_violation v JOIN catalog.quality_run q ON q.quality_run_id = v.quality_run_id
     WHERE v.rule_id = p_rule_id AND q.dataset_id = p_dataset_id
       AND (v.quality_run_id = v_run OR v.status = 'WAIVED'))
  INSERT INTO catalog.quality_violation (quality_run_id, rule_id, focus_node, result_path, message, severity)
  SELECT v_run, p_rule_id, f.focus_node, f.result_path, f.message, r.severity
    FROM gov.quality_findings(p_violations, r.label_ko) f
   WHERE NOT EXISTS (SELECT 1 FROM known k WHERE k.focus_node = f.focus_node AND k.result_path IS NOT DISTINCT FROM f.result_path);
  GET DIAGNOSTICS n_new = ROW_COUNT;
  n_waived := greatest(0, (SELECT count(*) FROM gov.quality_findings(p_violations, r.label_ko))::int - n_new - n_kept);

  IF p_dataset_id IS NOT NULL THEN
    PERFORM gov.refresh_dataset_quality(p_dataset_id);
  END IF;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, row_count, result)
  VALUES ('UI', 'run_quality_rule', p_dataset_id, 'catalog.quality_rule:' || p_rule_id, n_v, 'OK');
  RETURN jsonb_build_object('quality_run_id', v_run, 'focus_count', p_focus_count, 'violation_count', n_v, 'conformance_rate', v_rate,
                            'new_violations', n_new, 'carried_violations', n_kept, 'auto_resolved', n_auto, 'waived_skipped', n_waived);
END $$;
REVOKE ALL ON FUNCTION gov.record_quality_run(text, text, bigint, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.record_quality_run(text, text, bigint, jsonb) TO lake_app;
REVOKE ALL ON FUNCTION gov.refresh_dataset_quality(text), gov.quality_rule_changed() FROM PUBLIC;

-- 이미 쌓인 중복 정리: 같은 규칙·데이터셋·대상·속성으로 열린 위반이 여럿이면 가장 최근 것만 남기고 자동 해결
WITH ranked AS (
  SELECT v.violation_id, row_number() OVER (PARTITION BY v.rule_id, q.dataset_id, v.focus_node, coalesce(v.result_path, '')
                                            ORDER BY q.executed_at DESC, v.violation_id DESC) AS rn
    FROM catalog.quality_violation v JOIN catalog.quality_run q ON q.quality_run_id = v.quality_run_id
   WHERE v.status IN ('OPEN', 'ACK'))
UPDATE catalog.quality_violation v SET status = 'FIXED', resolved_at = now()
  FROM ranked WHERE ranked.violation_id = v.violation_id AND ranked.rn > 1;

-- 기존 데이터셋 점수도 새 기준으로 한 번 다시 종합
DO $$ DECLARE d text; BEGIN
  FOR d IN SELECT DISTINCT q.dataset_id FROM catalog.quality_run q JOIN catalog.quality_rule r ON r.rule_id = q.rule_id LOOP
    PERFORM gov.refresh_dataset_quality(d);
  END LOOP;
END $$;

-- ── 3) 시맨틱 존 게이트 ──────────────────────────────────────────────────
-- 시맨틱 존으로 가는 파이프라인이 읽는 원천(계보 간선)이 품질 부적합이면 막는다.
CREATE OR REPLACE FUNCTION gov.semantic_blockers(p_pipeline_id text DEFAULT NULL)
RETURNS TABLE (pipeline_id text, pipeline_label text, dataset_id text, dataset_title text, quality_score numeric, quality_status text)
LANGUAGE sql STABLE SET search_path = pg_catalog AS $$   -- 부르는 사람 권한(RLS)으로: 내 회사 데이터셋만
  SELECT DISTINCT p.pipeline_id::text, p.label_ko::text, d.dataset_id::text, d.title_ko::text, d.quality_score, d.quality_status::text
    FROM catalog.pipeline p
    JOIN catalog.lineage_edge e ON e.pipeline_id = p.pipeline_id
    JOIN catalog.dataset d ON d.dataset_id = e.from_dataset_id
   WHERE p.to_zone = 'SEMANTIC' AND p.enabled AND d.quality_status = 'FAIL'
     AND (p_pipeline_id IS NULL OR p.pipeline_id = p_pipeline_id)
   ORDER BY 1, 3
$$;

CREATE OR REPLACE FUNCTION gov.semantic_gate() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_list text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM catalog.pipeline WHERE pipeline_id = NEW.pipeline_id AND to_zone = 'SEMANTIC') THEN
    RETURN NEW;
  END IF;
  SELECT string_agg(DISTINCT d.dataset_id, ', ') INTO v_list
    FROM catalog.lineage_edge e JOIN catalog.dataset d ON d.dataset_id = e.from_dataset_id
   WHERE e.pipeline_id = NEW.pipeline_id AND d.quality_status = 'FAIL'
     AND (NEW.enterprise_id IS NULL OR d.enterprise_id IS NULL OR d.enterprise_id = NEW.enterprise_id);
  IF v_list IS NOT NULL THEN
    RAISE EXCEPTION '품질 부적합 데이터셋(%)이 있어 시맨틱 존 반영(%)을 시작할 수 없습니다. 원천 데이터를 고쳐 다시 넣고 품질 규칙을 다시 돌린 뒤 시작하세요', v_list, NEW.pipeline_id
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION gov.semantic_gate() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.semantic_blockers(text) TO lake_app;
DROP TRIGGER IF EXISTS tr_semantic_gate ON catalog.job_run;
-- 파이프라인은 시작할 때 RUNNING 으로 등록한다. 지난 기록을 옮겨 싣는 적재(SUCCESS 등)는 막지 않는다.
CREATE TRIGGER tr_semantic_gate BEFORE INSERT ON catalog.job_run
  FOR EACH ROW WHEN (NEW.status = 'RUNNING') EXECUTE FUNCTION gov.semantic_gate();
