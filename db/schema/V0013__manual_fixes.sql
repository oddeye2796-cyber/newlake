-- V0013 · 매뉴얼을 쓰며 찾은 문제 고치기
--   1) 한글 엔터티(파일) 이름이 'raw.<원천>.___' 처럼 밑줄만 남아 서로 다른 파일이 한 데이터셋에 섞이던 것
--   2) 되돌리기가 이 배치가 덮어쓴 표준 행을 이전 값으로 돌리지 않고 지우던 것 (덮어쓰기 전 행을 보관해 둔다)
--   3) 품질 규칙 목록의 최근 결과가 '위반이 있었던 마지막 실행' 기준이던 것 (실행 기록에 규칙을 남긴다)
--   4) 한 번이라도 표준 존에 넣은 원천 데이터셋을 지울 수 없던 것 (그 데이터셋의 계보·매핑은 함께 지운다)

-- ── 1) 데이터셋 ID 의 엔터티 조각 ─────────────────────────────────────────
-- 영문·숫자는 그대로 소문자로, 나머지는 '_' 로. 한글처럼 ASCII 가 아닌 글자가 있으면 원래 이름의 짧은 해시를 붙여
-- '발주_예시' 와 '실적_예시' 가 같은 ID 가 되지 않게 한다. 비어 있으면 NULL.
CREATE OR REPLACE FUNCTION gov.entity_slug(p_entity text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $$
  SELECT CASE
           WHEN btrim(coalesce(p_entity, '')) = '' THEN NULL
           WHEN p_entity ~ '[^\x01-\x7F]' THEN
             concat_ws('_', nullif(btrim(lower(regexp_replace(p_entity, '[^A-Za-z0-9_]+', '_', 'g')), '_'), ''),
                       'h' || left(md5(btrim(p_entity)), 8))
           ELSE nullif(btrim(lower(regexp_replace(p_entity, '[^A-Za-z0-9_]+', '_', 'g')), '_'), '')
         END
$$;
GRANT EXECUTE ON FUNCTION gov.entity_slug(text) TO lake_app;

CREATE OR REPLACE FUNCTION gov.ingest_records(
    p_source_system_id text, p_entity text, p_rows jsonb,
    p_file_name text DEFAULT NULL, p_format text DEFAULT 'csv', p_mime_type text DEFAULT NULL,
    p_byte_size bigint DEFAULT NULL, p_sha256 text DEFAULT NULL, p_title text DEFAULT NULL, p_columns text[] DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent   text := gov.require_ingest_role();
  v_user  text := current_setting('app.user_id', true);
  v_ent_slug text := gov.entity_slug(p_entity);
  v_ds    text;
  v_run   uuid;
  v_batch uuid;
  v_n     bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM catalog.source_system WHERE source_system_id = p_source_system_id AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '원천 % 가 없거나 다른 회사 것입니다', p_source_system_id;
  END IF;
  IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN RAISE EXCEPTION '적재할 행이 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_rows) e WHERE jsonb_typeof(e) <> 'object') THEN
    RAISE EXCEPTION '행은 {열: 값} 형태여야 합니다';
  END IF;
  IF v_ent_slug IS NULL THEN RAISE EXCEPTION '엔터티 이름이 비었습니다'; END IF;
  v_n  := jsonb_array_length(p_rows);
  v_ds := left('raw.' || lower(p_source_system_id) || '.' || v_ent_slug, 150);

  IF EXISTS (SELECT 1 FROM catalog.dataset WHERE dataset_id = v_ds AND enterprise_id IS DISTINCT FROM v_ent) THEN
    RAISE EXCEPTION '데이터셋 % 는 다른 회사 것입니다', v_ds;
  END IF;
  INSERT INTO catalog.dataset (dataset_id, title_ko, zone_id, source_system_id, location_uri, format, ingest_mode,
                               record_count, last_ingested_at, owner_user_id, tags, enterprise_id)
  VALUES (v_ds, coalesce(nullif(p_title, ''), p_source_system_id || ' ' || p_entity), 'RAW', p_source_system_id,
          'upload://' || p_source_system_id || '/' || v_ent_slug || '/', lower(coalesce(p_format, 'csv')),
          CASE WHEN p_file_name IS NULL THEN 'batch' ELSE 'file' END, 0, now(), v_user, ARRAY['console'], v_ent)
  ON CONFLICT (dataset_id) DO NOTHING;

  INSERT INTO catalog.job_run (pipeline_id, status, rows_in, enterprise_id, code_version)
  VALUES ('p-console-upload', 'RUNNING', v_n, v_ent, 'console') RETURNING run_id INTO v_run;

  INSERT INTO raw.ingest_batch (source_system_id, dataset_id, job_run_id, record_count, byte_size, checksum, columns)
  VALUES (p_source_system_id, v_ds, v_run, v_n, p_byte_size, p_sha256, p_columns) RETURNING batch_id INTO v_batch;

  INSERT INTO raw.landing_record (batch_id, record_seq, source_entity, op, payload)
  SELECT v_batch, e.ord, left(p_entity, 100), 'S', e.val
    FROM jsonb_array_elements(p_rows) WITH ORDINALITY AS e(val, ord);

  IF p_file_name IS NOT NULL THEN
    INSERT INTO raw.landing_file (batch_id, object_uri, file_name, mime_type, byte_size, sha256)
    VALUES (v_batch, 'upload://' || v_batch || '/' || p_file_name, p_file_name, p_mime_type, p_byte_size,
            coalesce(p_sha256, encode(sha256(convert_to(p_rows::text, 'UTF8')), 'hex')));
  END IF;

  -- 필드 목록 (처음 보는 열만 추가)
  INSERT INTO catalog.dataset_field (dataset_id, field_name, data_type)
  SELECT DISTINCT ON (k) v_ds, left(k, 100), 'text'
    FROM jsonb_array_elements(p_rows) e, jsonb_object_keys(e) k
  ON CONFLICT (dataset_id, field_name) DO NOTHING;

  UPDATE catalog.dataset SET record_count = coalesce(record_count, 0) + v_n, last_ingested_at = now(), updated_at = now()
   WHERE dataset_id = v_ds;
  UPDATE catalog.job_run SET status = 'SUCCESS', rows_out = v_n, ended_at = now() WHERE run_id = v_run;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, row_count)
  VALUES ('UI', 'ingest', v_ds, 'raw.ingest_batch:' || v_batch, v_n);
  RETURN v_batch;
END $$;


-- ── 2) 덮어쓰기 전 표준 행 보관 → 되돌리면 이전 값으로 복원 ─────────────────
CREATE TABLE IF NOT EXISTS raw.std_preimage (
    preimage_id  BIGSERIAL PRIMARY KEY,
    batch_id     UUID NOT NULL REFERENCES raw.ingest_batch(batch_id) ON DELETE CASCADE,  -- 덮어쓴 배치
    table_name   TEXT NOT NULL,                                                           -- ksx.<표>
    prior        JSONB NOT NULL,                                                          -- 덮어쓰기 직전 행
    captured_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_std_preimage_batch ON raw.std_preimage (batch_id, table_name);
REVOKE ALL ON raw.std_preimage FROM PUBLIC;

-- 적재 배치가 표준 행을 덮어쓸 때(lake_batch_id 가 바뀔 때) 직전 행을 남긴다. 같은 배치를 다시 넣어도 처음 것만 남는다.
CREATE OR REPLACE FUNCTION raw.capture_std_preimage() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
  IF NEW.lake_batch_id IS NOT NULL AND NEW.lake_batch_id IS DISTINCT FROM OLD.lake_batch_id
     AND EXISTS (SELECT 1 FROM raw.ingest_batch b WHERE b.batch_id = NEW.lake_batch_id) THEN
    INSERT INTO raw.std_preimage (batch_id, table_name, prior) VALUES (NEW.lake_batch_id, TG_ARGV[0], to_jsonb(OLD));
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION raw.capture_std_preimage() FROM PUBLIC;

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.oid::regclass AS rel, n.nspname || '.' || c.relname AS name
             FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'ksx' AND c.relkind IN ('r', 'p') AND NOT c.relispartition
              AND EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = c.oid AND a.attname = 'lake_batch_id' AND NOT a.attisdropped)
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_std_preimage ON %s', r.rel);
    EXECUTE format('CREATE TRIGGER trg_std_preimage BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION raw.capture_std_preimage(%L)', r.rel, r.name);
  END LOOP;
END $$;

-- 되돌리기: 이 배치가 넣은 표준 행·확장 값을 빼고, 이 배치가 덮어썼던 행은 덮어쓰기 전 값으로 되살린다.
-- 뒤 배치가 다시 덮어쓴 행은 그대로 두고(키가 겹쳐 건너뜀), 이전 값이 이미 되돌린 배치의 것이면 되살리지 않는다.
CREATE OR REPLACE FUNCTION gov.rollback_batch(p_batch_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role(); b raw.ingest_batch; n bigint := 0; n_ext bigint := 0; n_back bigint := 0; n_one bigint;
        v_std text; t record; v_cols text;
BEGIN
  SELECT * INTO b FROM raw.ingest_batch WHERE batch_id = p_batch_id FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  IF b.std_table IS NULL OR b.status NOT IN ('STANDARDIZED', 'REJECTED') THEN RAISE EXCEPTION '표준 존에 넣지 않은 배치는 되돌릴 것이 없습니다'; END IF;
  IF to_regclass(b.std_table) IS NULL OR b.std_table !~ '^ksx\.[a-z][a-z0-9_]{0,62}$' THEN RAISE EXCEPTION '표준 표 % 가 없습니다', b.std_table; END IF;
  EXECUTE format('DELETE FROM %s WHERE lake_batch_id = $1 AND enterprise_id = $2', b.std_table) USING p_batch_id, v_ent;
  GET DIAGNOSTICS n = ROW_COUNT;
  DELETE FROM ksx.extension_attribute WHERE lake_batch_id = p_batch_id AND enterprise_id = v_ent;
  GET DIAGNOSTICS n_ext = ROW_COUNT;

  FOR t IN SELECT DISTINCT p.table_name FROM raw.std_preimage p WHERE p.batch_id = p_batch_id LOOP
    CONTINUE WHEN t.table_name !~ '^ksx\.[a-z][a-z0-9_]{0,62}$' OR to_regclass(t.table_name) IS NULL;
    SELECT string_agg(format('%I', a.attname), ', ' ORDER BY a.attnum) INTO v_cols
      FROM pg_attribute a WHERE a.attrelid = to_regclass(t.table_name) AND a.attnum > 0 AND NOT a.attisdropped
       AND a.attgenerated = '' AND a.attidentity <> 'a';
    EXECUTE format(
      'INSERT INTO %1$s (%2$s) SELECT %3$s FROM raw.std_preimage p CROSS JOIN LATERAL jsonb_populate_record(NULL::%1$s, p.prior) x'
      ' WHERE p.batch_id = $1 AND p.table_name = $2 AND x.enterprise_id = $3'
      '   AND NOT EXISTS (SELECT 1 FROM raw.ingest_batch ob WHERE ob.batch_id = x.lake_batch_id AND ob.status = ''LANDED'')'
      ' ORDER BY p.preimage_id ON CONFLICT DO NOTHING',
      t.table_name, v_cols, (SELECT string_agg('x.' || c, ', ') FROM unnest(string_to_array(v_cols, ', ')) c))
      USING p_batch_id, t.table_name, v_ent;
    GET DIAGNOSTICS n_one = ROW_COUNT;
    n_back := n_back + n_one;
  END LOOP;
  DELETE FROM raw.std_preimage WHERE batch_id = p_batch_id;

  SELECT dataset_id INTO v_std FROM catalog.dataset WHERE location_uri = 'postgresql://lake/' || b.std_table LIMIT 1;
  UPDATE raw.ingest_batch SET status = 'LANDED', std_table = NULL, std_job_run_id = NULL WHERE batch_id = p_batch_id;
  INSERT INTO catalog.job_run (pipeline_id, status, rows_in, rows_out, rows_rejected, ended_at, enterprise_id, code_version)
  VALUES ('p-console-std', 'SUCCESS', n, n_back, 0, now(), v_ent, 'console-rollback');
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text, row_count)
  VALUES ('UI', 'rollback_batch', b.dataset_id, 'raw.ingest_batch:' || p_batch_id, b.std_table, n);
  RETURN jsonb_build_object('batch_id', p_batch_id, 'table', b.std_table, 'std_dataset_id', v_std, 'rows', n,
                            'extension_rows', n_ext, 'restored_rows', n_back);
END $$;

-- ── 3) 품질 실행 기록에 규칙을 남긴다 (위반 0건 실행도 규칙 목록에 보이도록) ────────
ALTER TABLE catalog.quality_run ADD COLUMN IF NOT EXISTS rule_id VARCHAR(100) REFERENCES catalog.quality_rule(rule_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS ix_quality_run_rule ON catalog.quality_run (rule_id, executed_at DESC);
UPDATE catalog.quality_run q SET rule_id = v.rule_id
  FROM (SELECT DISTINCT ON (quality_run_id) quality_run_id, rule_id FROM catalog.quality_violation WHERE rule_id IS NOT NULL
         ORDER BY quality_run_id, violation_id) v
 WHERE q.quality_run_id = v.quality_run_id AND q.rule_id IS NULL;

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
  INSERT INTO catalog.quality_run (job_run_id, dataset_id, focus_count, violation_count, rule_id)
  VALUES (v_job, p_dataset_id, p_focus_count, n_v, p_rule_id) RETURNING quality_run_id, conformance_rate INTO v_run, v_rate;
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


-- ── 4) 원천 데이터셋 지우기 ───────────────────────────────────────────────
-- 적재 배치를 다 지운 원천 데이터셋은 계보 간선·매핑(과 아직 결정 안 된 확장 제안)을 함께 지운다.
-- 작업 기록(job_run)은 남기고 매핑 연결만 끊는다. 품질·접근 기록이 가리키면 여전히 거절한다.
CREATE OR REPLACE FUNCTION gov.delete_dataset(p_dataset_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('data_steward', 'data_engineer'); v_maps text[]; n_edge int; n_map int;
BEGIN
  IF NOT gov.dataset_visible(p_dataset_id, v_ent) THEN RAISE EXCEPTION '데이터셋 % 가 없습니다', p_dataset_id; END IF;
  IF EXISTS (SELECT 1 FROM catalog.dataset WHERE dataset_id = p_dataset_id AND zone_id <> 'RAW') THEN
    RAISE EXCEPTION '원천 존 데이터셋만 지울 수 있습니다. 표준·시맨틱·활용 존은 스키마에 묶여 있습니다';
  END IF;
  IF EXISTS (SELECT 1 FROM raw.ingest_batch WHERE dataset_id = p_dataset_id) THEN
    RAISE EXCEPTION '적재 배치가 남아 있습니다. 데이터 넣기 → 적재 기록에서 먼저 지우세요';
  END IF;
  IF EXISTS (SELECT 1 FROM catalog.quality_run WHERE dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM catalog.quality_rule WHERE target_dataset_id = p_dataset_id) THEN
    RAISE EXCEPTION '품질 규칙·검사 기록이 이 데이터셋을 가리키고 있어 지울 수 없습니다. 규칙의 대상을 바꾸거나 규칙을 끄세요';
  END IF;
  IF EXISTS (SELECT 1 FROM gov.access_request WHERE dataset_id = p_dataset_id)
     OR EXISTS (SELECT 1 FROM gov.access_policy WHERE target_dataset_id = p_dataset_id) THEN
    RAISE EXCEPTION '접근 요청·접근 정책이 이 데이터셋을 가리키고 있어 지울 수 없습니다';
  END IF;
  BEGIN
    v_maps := ARRAY(SELECT mapping_id::text FROM catalog.mapping WHERE source_dataset_id = p_dataset_id);
    UPDATE catalog.job_run SET mapping_id = NULL WHERE mapping_id::text = ANY (v_maps);
    DELETE FROM catalog.mapping WHERE mapping_id::text = ANY (v_maps);
    GET DIAGNOSTICS n_map = ROW_COUNT;
    DELETE FROM catalog.lineage_edge WHERE from_dataset_id = p_dataset_id OR to_dataset_id = p_dataset_id;
    GET DIAGNOSTICS n_edge = ROW_COUNT;
    DELETE FROM onto.extension_proposal WHERE dataset_id = p_dataset_id AND enterprise_id = v_ent AND status = 'PROPOSED';
    DELETE FROM catalog.dataset_field WHERE dataset_id = p_dataset_id;
    DELETE FROM catalog.dataset WHERE dataset_id = p_dataset_id;
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION '다른 기록(문서·작업 기록 등)이 이 데이터셋을 가리키고 있어 지울 수 없습니다';
  END;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, row_count)
  VALUES ('UI', 'delete_dataset', p_dataset_id, 'catalog.dataset:' || p_dataset_id, n_edge + n_map);
END $$;
