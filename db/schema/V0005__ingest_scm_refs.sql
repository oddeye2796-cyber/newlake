-- V0005: 데이터 넣기 보완
--   · 원천 종류에 SCM 추가
--   · 원천 지우기 (gov.delete_source)
--   · 표준화할 때 품목·공급사처럼 참조 마스터에 없는 코드를 키만으로 먼저 등록하는 선택지 (p_create_refs)

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
  IF p_system_type NOT IN ('ERP','MES','SCM','QMS','WMS','PLM','SCADA','SECS_GEM','EDMS','SENSOR','FILE') THEN
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

DROP FUNCTION IF EXISTS gov.standardize_batch(uuid, text, jsonb, text, text);

CREATE OR REPLACE FUNCTION gov.standardize_batch(p_batch_id uuid, p_table text, p_column_map jsonb,
                                                 p_site_id text DEFAULT NULL, p_plant_id text DEFAULT NULL,
                                                 p_create_refs boolean DEFAULT false)
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
  fk      record;
  v_refs  jsonb := '[]';   -- 없으면 새로 등록할 참조 마스터: [{rel, l:[로컬 열], r:[참조 열], names:[…], sql}]
  ref     jsonb;
  v_ro    jsonb;
  v_lv    text;
  v_skip  boolean;
  v_made  text[];
  n_made  int;
  v_refn  jsonb := '{}';   -- 표별 새로 등록한 행 수
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

  -- 참조 마스터 자동 등록: 그 마스터가 꼭 채워야 하는 열이 키·회사·사업장·공장뿐이고, 로컬 FK 열이 모두 대응됐을 때만
  IF p_create_refs THEN
    FOR fk IN
      SELECT c.confrelid,
             ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(n, i)
                     JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.n ORDER BY k.i) AS lcols,
             ARRAY(SELECT a.attname::text FROM unnest(c.confkey) WITH ORDINALITY k(n, i)
                     JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.n ORDER BY k.i) AS rcols
        FROM pg_constraint c
       WHERE c.conrelid = v_rel AND c.contype = 'f'
         AND c.confrelid NOT IN ('ksx.enterprise'::regclass, 'ksx.site'::regclass, 'ksx.plant'::regclass)
    LOOP
      CONTINUE WHEN EXISTS (SELECT 1 FROM unnest(fk.lcols) l WHERE l NOT IN ('enterprise_id', 'site_id', 'plant_id') AND NOT v_map ? l);
      CONTINUE WHEN EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = fk.confrelid AND a.attnum > 0 AND NOT a.attisdropped
                              AND a.attnotnull AND NOT a.atthasdef
                              AND NOT a.attname::text = ANY (fk.rcols || ARRAY['enterprise_id', 'site_id', 'plant_id']));
      DECLARE
        v_names text[] := ARRAY(SELECT a.attname::text FROM pg_attribute a WHERE a.attrelid = fk.confrelid AND a.attnum > 0
                                  AND NOT a.attisdropped AND a.attname LIKE '%\_name' AND v_map ? a.attname::text
                                  AND NOT a.attname::text = ANY (fk.rcols));
        v_ic text[] := ARRAY(SELECT a.attname::text FROM pg_attribute a WHERE a.attrelid = fk.confrelid AND a.attnum > 0
                               AND NOT a.attisdropped
                               AND (a.attname::text = ANY (fk.rcols || v_names || ARRAY['enterprise_id', 'site_id', 'plant_id',
                                      'lake_batch_id', 'lake_source_system', 'lake_loaded_at', 'lake_record_hash', 'lake_shacl_status']))
                             ORDER BY a.attnum);
      BEGIN
        v_refs := v_refs || jsonb_build_object('rel', fk.confrelid::regclass::text, 'l', to_jsonb(fk.lcols), 'r', to_jsonb(fk.rcols),
          'names', to_jsonb(v_names),
          'sql', format('INSERT INTO %s (%s) SELECT %s FROM jsonb_populate_record(NULL::%s, $1) ON CONFLICT DO NOTHING',
                        fk.confrelid::regclass, (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_ic) c),
                        (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_ic) c), fk.confrelid::regclass));
      END;
    END LOOP;
  END IF;

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
      v_made := '{}';
      FOR ref IN SELECT * FROM jsonb_array_elements(v_refs) LOOP
        v_ro := jsonb_build_object('enterprise_id', v_ent, 'site_id', v_obj ->> 'site_id', 'plant_id', v_obj ->> 'plant_id',
                  'lake_batch_id', p_batch_id, 'lake_source_system', b.source_system_id, 'lake_loaded_at', now(),
                  'lake_shacl_status', 'PENDING');
        v_skip := false;
        FOR i IN 0 .. jsonb_array_length(ref -> 'l') - 1 LOOP
          v_lv := CASE WHEN ref -> 'l' ->> i = 'enterprise_id' THEN v_ent ELSE v_obj ->> (ref -> 'l' ->> i) END;
          IF v_lv IS NULL THEN v_skip := true; EXIT; END IF;
          v_ro := v_ro || jsonb_build_object(ref -> 'r' ->> i, v_lv);
        END LOOP;
        CONTINUE WHEN v_skip;
        SELECT v_ro || coalesce(jsonb_object_agg(n, v_obj -> n), '{}') INTO v_ro FROM jsonb_array_elements_text(ref -> 'names') n;
        v_ro := v_ro || jsonb_build_object('lake_record_hash', encode(sha256(convert_to(v_ro::text, 'UTF8')), 'hex'));
        EXECUTE ref ->> 'sql' USING v_ro;
        GET DIAGNOSTICS n_made = ROW_COUNT;
        IF n_made > 0 THEN v_made := v_made || (ref ->> 'rel'); END IF;
      END LOOP;
      EXECUTE v_sql USING v_obj;
      n_out := n_out + 1;
      FOREACH k IN ARRAY v_made LOOP
        v_refn := v_refn || jsonb_build_object(k, coalesce((v_refn ->> k)::int, 0) + 1);
      END LOOP;
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
  VALUES ('UI', 'standardize', b.dataset_id, 'raw.ingest_batch:' || p_batch_id,
          'ksx.' || p_table || CASE WHEN v_refn <> '{}' THEN ' +refs ' || v_refn::text ELSE '' END, n_out,
          CASE WHEN n_out = 0 THEN 'ERROR' ELSE 'OK' END);
  RETURN jsonb_build_object('run_id', v_run, 'mapping_id', v_mapid, 'target', 'ksx.' || p_table, 'std_dataset_id', v_std,
                            'rows_in', n_in, 'rows_out', n_out, 'rows_rejected', n_rej, 'errors', v_errs,
                            'refs_created', v_refn);
END $$;

REVOKE ALL ON FUNCTION gov.standardize_batch(uuid, text, jsonb, text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.standardize_batch(uuid, text, jsonb, text, text, boolean) TO lake_app;

-- 원천 지우기. 원천 존 데이터(배치·적재 행·데이터셋·매핑·계보)가 있으면 p_purge 일 때만 함께 지운다.
-- 표준 존(ksx)에 이미 들어간 행은 남긴다 (lake_source_system 으로 출처가 남는다).
CREATE OR REPLACE FUNCTION gov.delete_source(p_source_system_id text, p_purge boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent  text := gov.require_ingest_role();
  v_ds   text[];
  v_b    uuid[];
  v_runs uuid[];
  v_maps text[];
  n_rec  bigint := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM catalog.source_system WHERE source_system_id = p_source_system_id AND enterprise_id = v_ent) THEN
    RAISE EXCEPTION '원천 % 가 없거나 다른 회사 것입니다', p_source_system_id;
  END IF;
  v_ds := ARRAY(SELECT dataset_id::text FROM catalog.dataset WHERE source_system_id = p_source_system_id);
  v_b  := ARRAY(SELECT batch_id FROM raw.ingest_batch WHERE source_system_id = p_source_system_id OR dataset_id::text = ANY (v_ds));
  IF (cardinality(v_ds) > 0 OR cardinality(v_b) > 0) AND NOT p_purge THEN
    RAISE EXCEPTION '원천 % 에 데이터셋 %개·적재 %건이 있습니다. 원천 존 데이터까지 함께 지우려면 함께 지우기를 고르세요',
      p_source_system_id, cardinality(v_ds), cardinality(v_b);
  END IF;
  BEGIN
    v_maps := ARRAY(SELECT mapping_id::text FROM catalog.mapping WHERE source_dataset_id::text = ANY (v_ds));
    v_runs := ARRAY(SELECT job_run_id FROM raw.ingest_batch WHERE batch_id = ANY (v_b) AND job_run_id IS NOT NULL
                    UNION SELECT std_job_run_id FROM raw.ingest_batch WHERE batch_id = ANY (v_b) AND std_job_run_id IS NOT NULL
                    UNION SELECT run_id FROM catalog.job_run WHERE mapping_id::text = ANY (v_maps));
    DELETE FROM raw.landing_file WHERE batch_id = ANY (v_b);
    DELETE FROM raw.landing_record WHERE batch_id = ANY (v_b);
    GET DIAGNOSTICS n_rec = ROW_COUNT;
    DELETE FROM raw.ingest_batch WHERE batch_id = ANY (v_b);
    DELETE FROM catalog.lineage_edge WHERE from_dataset_id::text = ANY (v_ds) OR to_dataset_id::text = ANY (v_ds);
    DELETE FROM catalog.job_run WHERE run_id = ANY (v_runs);
    DELETE FROM catalog.mapping WHERE mapping_id::text = ANY (v_maps);
    DELETE FROM catalog.dataset WHERE dataset_id::text = ANY (v_ds);
    DELETE FROM catalog.source_system WHERE source_system_id = p_source_system_id;
  EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION '원천 % 의 데이터가 품질 규칙·권한 정책·작업 기록 등에서 쓰이고 있어 지울 수 없습니다', p_source_system_id;
  END;
  INSERT INTO gov.audit_log (channel, action, object_ref, row_count, result)
  VALUES ('UI', 'delete_source', 'catalog.source_system:' || p_source_system_id, n_rec, 'OK');
  RETURN jsonb_build_object('source_system_id', p_source_system_id, 'datasets', cardinality(v_ds),
                            'batches', cardinality(v_b), 'records', n_rec);
END $$;

REVOKE ALL ON FUNCTION gov.delete_source(text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.delete_source(text, boolean) TO lake_app;
