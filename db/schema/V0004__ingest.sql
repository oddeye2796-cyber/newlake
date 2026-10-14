-- =============================================================================
-- V0004 — 관리 화면에서 데이터 넣기: 원천 연결 등록, 파일·DB 행을 원천 존에 적재, 표준 존으로 변환
--
-- 흐름: 원천 등록(gov.register_source) → 원천 존 적재(gov.ingest_records: 배치·레코드·파일 메타·데이터셋·필드)
--       → 표준 존 변환(gov.standardize_batch: 열 대응표대로 ksx.<표> 에 upsert, 매핑·작업 기록·계보)
-- lake_app 은 raw·catalog 에 쓰지 못한다. 모든 쓰기는 아래 SECURITY DEFINER 함수로만 하고,
-- 함수는 app.user_id 의 역할(admin·data_engineer·data_steward)과 회사·사업장·공장 범위를 직접 확인한다.
-- 비밀번호는 저장하지 않는다. secret_ref 는 운영 비밀 저장소(Vault 등)의 이름만 둔다.
-- =============================================================================

CREATE TABLE catalog.source_connection (
    source_system_id  VARCHAR(50) PRIMARY KEY REFERENCES catalog.source_system(source_system_id) ON DELETE CASCADE,
    db_kind           VARCHAR(20) NOT NULL CHECK (db_kind IN ('POSTGRESQL','MYSQL','MSSQL','ORACLE','REST','SFTP','FILE')),
    host              VARCHAR(255),
    port              INTEGER CHECK (port BETWEEN 1 AND 65535),
    database_name     VARCHAR(128),
    username          VARCHAR(128),
    secret_ref        VARCHAR(200),               -- 비밀번호 자체는 저장하지 않는다
    options           JSONB NOT NULL DEFAULT '{}',
    status            VARCHAR(10) NOT NULL DEFAULT 'UNTESTED' CHECK (status IN ('UNTESTED','OK','FAILED')),
    last_tested_at    TIMESTAMPTZ,
    last_error        TEXT,
    created_by        VARCHAR(50),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    enterprise_id     VARCHAR(50) NOT NULL
);
GRANT SELECT ON catalog.source_connection TO lake_app;
-- 배치를 마지막으로 표준 존에 넣은 작업
ALTER TABLE raw.ingest_batch ADD COLUMN std_job_run_id UUID REFERENCES catalog.job_run(run_id),
                             ADD COLUMN std_table VARCHAR(100),
                             ADD COLUMN columns TEXT[];   -- 원본 열 순서 (JSONB 는 키 순서를 바꾼다)
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog.source_connection TO lake_loader;
SELECT gov.apply_scope_policies();

-- 콘솔 적재용 파이프라인 정의 (공용)
INSERT INTO catalog.pipeline (pipeline_id, label_ko, from_zone, to_zone, engine, enabled) VALUES
  ('p-console-upload', '관리 화면 적재 (파일·DB)', NULL, 'RAW', 'lake-console', TRUE),
  ('p-console-std',    '관리 화면 표준 변환',       'RAW', 'STANDARD', 'lake-console', TRUE)
ON CONFLICT (pipeline_id) DO NOTHING;

-- 역할 확인 공통 ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION gov.require_ingest_role() RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_user text := nullif(current_setting('app.user_id', true), '');
  v_ent  text := nullif(current_setting('app.enterprise_id', true), '');
BEGIN
  IF v_user IS NULL OR v_ent IS NULL THEN RAISE EXCEPTION 'app.user_id 와 app.enterprise_id 가 필요합니다'; END IF;
  IF NOT EXISTS (SELECT 1 FROM gov.role_assignment ra
                  WHERE ra.user_id = v_user AND ra.enterprise_id = v_ent
                    AND ra.role_id IN ('admin', 'data_engineer', 'data_steward')
                    AND (ra.valid_until IS NULL OR ra.valid_until >= current_date)) THEN
    RAISE EXCEPTION '데이터 적재는 관리자·데이터 엔지니어·스튜어드만 할 수 있습니다';
  END IF;
  RETURN v_ent;
END $$;

-- 원천 등록·수정 ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION gov.register_source(
    p_source_system_id text, p_label text, p_system_type text, p_db_kind text,
    p_host text DEFAULT NULL, p_port int DEFAULT NULL, p_database text DEFAULT NULL,
    p_username text DEFAULT NULL, p_secret_ref text DEFAULT NULL, p_owner_dept text DEFAULT NULL,
    p_options jsonb DEFAULT '{}')
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_ingest_role();
  v_user text := current_setting('app.user_id', true);
  v_kind text;
BEGIN
  IF p_source_system_id !~ '^[A-Za-z0-9][A-Za-z0-9_-]{1,49}$' THEN
    RAISE EXCEPTION '원천 ID 는 영문·숫자·-·_ 2~50자여야 합니다';
  END IF;
  IF EXISTS (SELECT 1 FROM catalog.source_system WHERE source_system_id = p_source_system_id AND enterprise_id <> v_ent) THEN
    RAISE EXCEPTION '원천 ID % 는 이미 다른 회사에서 쓰고 있습니다', p_source_system_id;
  END IF;
  IF p_system_type NOT IN ('ERP','MES','QMS','WMS','PLM','SCADA','SECS_GEM','EDMS','SENSOR','FILE') THEN
    RAISE EXCEPTION '원천 종류 % 는 쓸 수 없습니다', p_system_type;
  END IF;
  v_kind := CASE p_db_kind WHEN 'REST' THEN 'REST' WHEN 'SFTP' THEN 'SFTP' WHEN 'FILE' THEN NULL ELSE 'JDBC' END;
  INSERT INTO catalog.source_system (source_system_id, label_ko, system_type, connection_kind, owner_dept, enterprise_id)
  VALUES (p_source_system_id, p_label, p_system_type, v_kind, p_owner_dept, v_ent)
  ON CONFLICT (source_system_id) DO UPDATE
     SET label_ko = EXCLUDED.label_ko, system_type = EXCLUDED.system_type,
         connection_kind = EXCLUDED.connection_kind, owner_dept = coalesce(EXCLUDED.owner_dept, catalog.source_system.owner_dept);
  INSERT INTO catalog.source_connection (source_system_id, db_kind, host, port, database_name, username, secret_ref,
                                         options, created_by, enterprise_id)
  VALUES (p_source_system_id, p_db_kind, p_host, p_port, p_database, p_username, p_secret_ref,
          coalesce(p_options, '{}'), v_user, v_ent)
  ON CONFLICT (source_system_id) DO UPDATE
     SET db_kind = EXCLUDED.db_kind, host = EXCLUDED.host, port = EXCLUDED.port, database_name = EXCLUDED.database_name,
         username = EXCLUDED.username, secret_ref = EXCLUDED.secret_ref, options = EXCLUDED.options,
         status = 'UNTESTED', last_tested_at = NULL, last_error = NULL;
  INSERT INTO gov.audit_log (channel, action, object_ref)
  VALUES ('UI', 'register_source', 'catalog.source_system:' || p_source_system_id);
  RETURN p_source_system_id;
END $$;

CREATE OR REPLACE FUNCTION gov.record_connection_test(p_source_system_id text, p_ok boolean, p_error text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role();
BEGIN
  UPDATE catalog.source_connection
     SET status = CASE WHEN p_ok THEN 'OK' ELSE 'FAILED' END, last_tested_at = now(), last_error = left(p_error, 1000)
   WHERE source_system_id = p_source_system_id AND enterprise_id = v_ent;
  IF NOT FOUND THEN RAISE EXCEPTION '원천 % 의 연결 정보가 없습니다', p_source_system_id; END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref, result)
  VALUES ('UI', 'test_source', 'catalog.source_system:' || p_source_system_id, CASE WHEN p_ok THEN 'OK' ELSE 'ERROR' END);
END $$;

-- 원천 존 적재 ------------------------------------------------------------------
-- p_rows: [{열: 값, …}, …]. 데이터셋 raw.<원천>.<엔터티> 가 없으면 만든다. 반환: 배치 ID.
-- 파일 실체는 아직 오브젝트 스토리지에 두지 않는다 → landing_file.object_uri 는 upload:// 로 표시하고 내용은 레코드로 남는다.
CREATE OR REPLACE FUNCTION gov.ingest_records(
    p_source_system_id text, p_entity text, p_rows jsonb,
    p_file_name text DEFAULT NULL, p_format text DEFAULT 'csv', p_mime_type text DEFAULT NULL,
    p_byte_size bigint DEFAULT NULL, p_sha256 text DEFAULT NULL, p_title text DEFAULT NULL, p_columns text[] DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent   text := gov.require_ingest_role();
  v_user  text := current_setting('app.user_id', true);
  v_ent_slug text := lower(regexp_replace(p_entity, '[^A-Za-z0-9_]+', '_', 'g'));
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
  IF v_ent_slug = '' OR v_ent_slug = '_' THEN RAISE EXCEPTION '엔터티 이름이 비었습니다'; END IF;
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

-- 적재 기록·미리보기 (lake_app 은 raw 를 직접 읽지 못한다) ----------------------
CREATE OR REPLACE FUNCTION gov.ingest_batches(p_limit int DEFAULT 50)
RETURNS TABLE (batch_id uuid, source_system_id text, dataset_id text, received_at timestamptz, record_count bigint,
               byte_size bigint, status text, file_name text, source_entity text,
               std_rows_out bigint, std_rows_rejected bigint, std_table text, columns text[])
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role();
BEGIN
  RETURN QUERY
  SELECT b.batch_id, b.source_system_id::text, b.dataset_id::text, b.received_at, b.record_count, b.byte_size, b.status::text,
         f.file_name::text,
         (SELECT r.source_entity::text FROM raw.landing_record r WHERE r.batch_id = b.batch_id LIMIT 1),
         s.rows_out, s.rows_rejected, b.std_table::text, b.columns
    FROM raw.ingest_batch b
    JOIN catalog.dataset d ON d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent
    LEFT JOIN LATERAL (SELECT lf.file_name FROM raw.landing_file lf WHERE lf.batch_id = b.batch_id LIMIT 1) f ON TRUE
    LEFT JOIN catalog.job_run s ON s.run_id = b.std_job_run_id
   ORDER BY b.received_at DESC
   LIMIT least(greatest(p_limit, 1), 500);
END $$;

CREATE OR REPLACE FUNCTION gov.ingest_batch_preview(p_batch_id uuid, p_limit int DEFAULT 20)
RETURNS TABLE (record_seq bigint, payload jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM raw.ingest_batch b JOIN catalog.dataset d ON d.dataset_id = b.dataset_id
                  WHERE b.batch_id = p_batch_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  RETURN QUERY SELECT r.record_seq, r.payload FROM raw.landing_record r
                WHERE r.batch_id = p_batch_id ORDER BY r.record_seq LIMIT least(greatest(p_limit, 1), 200);
END $$;

-- 표준 존 변환 ------------------------------------------------------------------
-- p_table: ksx 표 이름(예: 'lot'). p_column_map: {"원천 열": "표준 열", …}.
-- p_site_id·p_plant_id: 원천 행에 사업장·공장이 없을 때 쓸 기본값. 회사는 항상 로그인 사용자의 회사.
-- 행마다 하위 트랜잭션으로 upsert 하고 FK 를 즉시 검사한다. 실패·범위 밖 행은 거부로 세고 사유를 돌려준다.
CREATE OR REPLACE FUNCTION gov.standardize_batch(p_batch_id uuid, p_table text, p_column_map jsonb,
                                                 p_site_id text DEFAULT NULL, p_plant_id text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent   text := gov.require_ingest_role();
  v_user  text := current_setting('app.user_id', true);
  b       raw.ingest_batch;
  v_rel   regclass;
  v_class text;
  v_std   text;
  v_cols  text[];          -- 표의 실제 열
  v_pk    text[];
  v_set   text[];          -- 이번에 채우는 열
  v_upd   text;
  v_sql   text;
  v_map   jsonb := '{}';
  v_run   uuid;
  v_mapid text;
  v_ver   int;
  rec     record;
  v_obj   jsonb;
  n_in bigint := 0; n_out bigint := 0; n_rej bigint := 0;
  v_errs  jsonb := '[]';
  k text; v text;
BEGIN
  SELECT * INTO b FROM raw.ingest_batch WHERE batch_id = p_batch_id FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  IF p_table !~ '^[a-z][a-z0-9_]{0,62}$' OR to_regclass('ksx.' || p_table) IS NULL THEN
    RAISE EXCEPTION '표준 표 % 가 없습니다', p_table;
  END IF;
  v_rel := ('ksx.' || p_table)::regclass;
  SELECT class_iri INTO v_class FROM onto.class WHERE physical_table = p_table ORDER BY is_standard DESC LIMIT 1;
  SELECT dataset_id INTO v_std FROM catalog.dataset WHERE location_uri = 'postgresql://lake/ksx.' || p_table LIMIT 1;

  SELECT array_agg(attname::text ORDER BY attnum) INTO v_cols
    FROM pg_attribute WHERE attrelid = v_rel AND attnum > 0 AND NOT attisdropped;
  SELECT array_agg(a.attname::text ORDER BY array_position(i.indkey::int2[], a.attnum)) INTO v_pk
    FROM pg_index i JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
   WHERE i.indrelid = v_rel AND i.indisprimary;

  -- 대응표 검사: 표준 열은 실제 열이어야 하고, 회사·적재 메타 열은 직접 채울 수 없다
  FOR k, v IN SELECT * FROM jsonb_each_text(coalesce(p_column_map, '{}')) LOOP
    CONTINUE WHEN v IS NULL OR v = '';
    IF NOT v = ANY (v_cols) THEN RAISE EXCEPTION '표 % 에 열 % 가 없습니다', p_table, v; END IF;
    IF v = 'enterprise_id' OR v LIKE 'lake\_%' THEN RAISE EXCEPTION '열 % 는 직접 채울 수 없습니다', v; END IF;
    IF v_map ? v THEN RAISE EXCEPTION '표준 열 % 에 원천 열이 둘 이상 대응됩니다', v; END IF;
    v_map := v_map || jsonb_build_object(v, k);
  END LOOP;
  IF v_map = '{}' THEN RAISE EXCEPTION '대응시킨 열이 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM unnest(v_pk) c WHERE c NOT IN ('enterprise_id', 'site_id', 'plant_id') AND NOT v_map ? c) THEN
    RAISE EXCEPTION '기본키 열(%)을 모두 대응시켜야 합니다', array_to_string(v_pk, ', ');
  END IF;

  v_set := ARRAY(SELECT jsonb_object_keys(v_map)) || ARRAY['enterprise_id'];
  IF 'site_id' = ANY (v_cols) AND NOT 'site_id' = ANY (v_set) THEN v_set := v_set || ARRAY['site_id']; END IF;
  IF 'plant_id' = ANY (v_cols) AND NOT 'plant_id' = ANY (v_set) THEN v_set := v_set || ARRAY['plant_id']; END IF;
  v_set := v_set || ARRAY(SELECT c FROM unnest(ARRAY['lake_batch_id','lake_source_system','lake_loaded_at',
                                                       'lake_record_hash','lake_shacl_status']) c WHERE c = ANY (v_cols));
  SELECT string_agg(format('%I = EXCLUDED.%I', c, c), ', ') INTO v_upd FROM unnest(v_set) c WHERE NOT c = ANY (v_pk);
  v_sql := format('INSERT INTO %s (%s) SELECT %s FROM jsonb_populate_record(NULL::%s, $1) ON CONFLICT (%s) DO %s',
                  v_rel, (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_set) c),
                  (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_set) c), v_rel,
                  (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_pk) c),
                  CASE WHEN v_upd IS NULL THEN 'NOTHING' ELSE 'UPDATE SET ' || v_upd END);

  SELECT coalesce(max(version_no), 0) + 1 INTO v_ver FROM catalog.mapping WHERE source_dataset_id = b.dataset_id;
  IF v_class IS NOT NULL THEN
    v_mapid := left('console/' || b.dataset_id || '→ksx.' || p_table || '@v' || v_ver, 100);
    INSERT INTO catalog.mapping (mapping_id, source_dataset_id, target_class_iri, kind, version_no, status, approved_by, approved_at)
    VALUES (v_mapid, b.dataset_id, v_class, 'SQL', v_ver, 'APPROVED', v_user, now());
  END IF;
  INSERT INTO catalog.job_run (pipeline_id, mapping_id, status, enterprise_id, code_version)
  VALUES ('p-console-std', v_mapid, 'RUNNING', v_ent, 'console') RETURNING run_id INTO v_run;

  SET CONSTRAINTS ALL IMMEDIATE;   -- 행마다 FK 를 바로 검사해 그 행만 거부한다
  FOR rec IN SELECT r.record_seq, r.payload FROM raw.landing_record r WHERE r.batch_id = p_batch_id ORDER BY r.record_seq LOOP
    n_in := n_in + 1;
    SELECT jsonb_object_agg(t.key, nullif(btrim(rec.payload ->> (t.value #>> '{}')), ''))
      INTO v_obj FROM jsonb_each(v_map) t;
    v_obj := v_obj || jsonb_build_object('enterprise_id', v_ent,
               'lake_batch_id', p_batch_id, 'lake_source_system', b.source_system_id, 'lake_loaded_at', now(),
               'lake_record_hash', encode(sha256(convert_to(rec.payload::text, 'UTF8')), 'hex'),
               'lake_shacl_status', 'PENDING');
    IF 'site_id' = ANY (v_cols) AND (v_obj ->> 'site_id') IS NULL THEN v_obj := v_obj || jsonb_build_object('site_id', p_site_id); END IF;
    IF 'plant_id' = ANY (v_cols) AND (v_obj ->> 'plant_id') IS NULL THEN v_obj := v_obj || jsonb_build_object('plant_id', p_plant_id); END IF;
    BEGIN
      IF NOT gov.scope_ok(v_ent, v_obj ->> 'site_id', v_obj ->> 'plant_id') THEN
        RAISE EXCEPTION '사업장 %·공장 % 는 내 범위 밖입니다', v_obj ->> 'site_id', v_obj ->> 'plant_id';
      END IF;
      EXECUTE v_sql USING v_obj;
      n_out := n_out + 1;
    EXCEPTION WHEN OTHERS THEN
      n_rej := n_rej + 1;
      IF jsonb_array_length(v_errs) < 20 THEN
        v_errs := v_errs || jsonb_build_object('record_seq', rec.record_seq, 'error', left(SQLERRM, 300));
      END IF;
    END;
  END LOOP;
  SET CONSTRAINTS ALL DEFERRED;

  UPDATE catalog.job_run
     SET status = CASE WHEN n_out = 0 THEN 'FAILED' WHEN n_rej > 0 THEN 'PARTIAL' ELSE 'SUCCESS' END,
         rows_in = n_in, rows_out = n_out, rows_rejected = n_rej, ended_at = now(),
         error_message = CASE WHEN n_rej > 0 THEN left(v_errs ->> 0, 1000) END
   WHERE run_id = v_run;
  UPDATE raw.ingest_batch SET status = CASE WHEN n_out = 0 THEN 'REJECTED' ELSE 'STANDARDIZED' END,
         std_job_run_id = v_run, std_table = 'ksx.' || p_table WHERE batch_id = p_batch_id;

  -- 필드 매핑과 계보
  UPDATE catalog.dataset_field f SET mapping_method = 'human', mapping_status = 'APPROVED', mapping_confidence = 1,
         label_ko = coalesce(f.label_ko, col_description(v_rel, (SELECT attnum FROM pg_attribute WHERE attrelid = v_rel AND attname = m.key)))
    FROM jsonb_each_text(v_map) m WHERE f.dataset_id = b.dataset_id AND f.field_name = m.value;
  IF v_std IS NOT NULL AND n_out > 0 THEN
    INSERT INTO catalog.lineage_edge (from_dataset_id, to_dataset_id, pipeline_id, field_map, enterprise_id)
    VALUES (b.dataset_id, v_std, 'p-console-std',
            (SELECT jsonb_object_agg(key, jsonb_build_array(value)) FROM jsonb_each(v_map)), v_ent)
    ON CONFLICT (from_dataset_id, to_dataset_id, pipeline_id) DO UPDATE SET field_map = EXCLUDED.field_map;
    UPDATE catalog.dataset SET last_ingested_at = now(), updated_at = now() WHERE dataset_id = v_std;
  END IF;
  IF v_class IS NOT NULL THEN
    UPDATE catalog.dataset SET represents_class_iri = coalesce(represents_class_iri, v_class) WHERE dataset_id = b.dataset_id;
  END IF;

  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text, row_count, result)
  VALUES ('UI', 'standardize', b.dataset_id, 'raw.ingest_batch:' || p_batch_id, 'ksx.' || p_table, n_out,
          CASE WHEN n_out = 0 THEN 'ERROR' ELSE 'OK' END);
  RETURN jsonb_build_object('run_id', v_run, 'mapping_id', v_mapid, 'target', 'ksx.' || p_table, 'std_dataset_id', v_std,
                            'rows_in', n_in, 'rows_out', n_out, 'rows_rejected', n_rej, 'errors', v_errs);
END $$;

REVOKE ALL ON FUNCTION gov.require_ingest_role(), gov.register_source(text, text, text, text, text, int, text, text, text, text, jsonb),
  gov.record_connection_test(text, boolean, text), gov.ingest_records(text, text, jsonb, text, text, text, bigint, text, text, text[]),
  gov.ingest_batches(int), gov.ingest_batch_preview(uuid, int), gov.standardize_batch(uuid, text, jsonb, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.require_ingest_role(), gov.register_source(text, text, text, text, text, int, text, text, text, text, jsonb),
  gov.record_connection_test(text, boolean, text), gov.ingest_records(text, text, jsonb, text, text, text, bigint, text, text, text[]),
  gov.ingest_batches(int), gov.ingest_batch_preview(uuid, int), gov.standardize_batch(uuid, text, jsonb, text, text) TO lake_app;
