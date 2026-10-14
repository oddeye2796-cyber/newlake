-- V0009: 표준 존 변환 — 순번 기본키(…_sequence, 정수)가 원천에 없으면 1 로 채운다.
-- 실제 MES 실적 내보내기(배정번호·작업일·양품수량…)에는 KS X 9101 의 생산실적순번 같은 열이 없어
-- 생산실적 표로 넣을 길이 없었다. 식별자만 맞추면 순번은 1 (한 행 = 한 건) 로 들어간다.
-- 그 밖의 동작은 V0005 의 gov.standardize_batch 와 같다.

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
  v_seq   text[];          -- 원천에 없어 1 로 채우는 순번 기본키 열 (…_sequence integer)
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
  -- 순번 기본키(…_sequence, 정수)는 현장 파일에 거의 없다. 대응이 없으면 1 로 채운다 (한 행 = 한 건).
  v_seq := ARRAY(SELECT a.attname::text FROM pg_attribute a
                  WHERE a.attrelid = v_rel AND a.attname::text = ANY (v_pk) AND a.attname::text LIKE '%\_sequence'
                    AND a.atttypid IN ('integer'::regtype, 'smallint'::regtype, 'bigint'::regtype) AND NOT v_map ? a.attname::text);
  IF EXISTS (SELECT 1 FROM unnest(v_pk) c WHERE c NOT IN ('enterprise_id', 'site_id', 'plant_id') AND NOT v_map ? c AND NOT c = ANY (v_seq)) THEN
    RAISE EXCEPTION '기본키 열(%)을 모두 대응시켜야 합니다', array_to_string(v_pk, ', ');
  END IF;

  v_set := ARRAY(SELECT jsonb_object_keys(v_map)) || ARRAY['enterprise_id'] || v_seq;
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
    FOREACH k IN ARRAY v_seq LOOP v_obj := v_obj || jsonb_build_object(k, 1); END LOOP;
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

-- 확장 속성 보관도 같은 규칙: 순번 기본키가 대응에 없으면 레코드 키에 1 을 쓴다 (그 밖은 V0008 과 같다).
CREATE OR REPLACE FUNCTION gov.store_extension_attributes(p_batch_id uuid, p_table text, p_key_map jsonb, p_attrs jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent text := gov.require_ingest_role();
  b raw.ingest_batch;
  v_pk text[]; rec record; k text; v_key text; v_part text; n bigint := 0; v_cols int := 0;
  v_skip boolean;
BEGIN
  SELECT * INTO b FROM raw.ingest_batch WHERE batch_id = p_batch_id;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  IF p_table !~ '^[a-z][a-z0-9_]{0,62}$' OR to_regclass('ksx.' || p_table) IS NULL THEN RAISE EXCEPTION '표준 표 % 가 없습니다', p_table; END IF;
  SELECT count(*) INTO v_cols FROM jsonb_object_keys(coalesce(p_attrs, '{}'));
  IF v_cols = 0 THEN RETURN jsonb_build_object('rows', 0, 'columns', 0); END IF;
  SELECT array_agg(a.attname::text ORDER BY array_position(i.indkey::int2[], a.attnum)) INTO v_pk
    FROM pg_index i JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
   WHERE i.indrelid = ('ksx.' || p_table)::regclass AND i.indisprimary;
  FOR rec IN SELECT r.payload FROM raw.landing_record r WHERE r.batch_id = p_batch_id ORDER BY r.record_seq LOOP
    v_key := ''; v_skip := false;
    FOREACH k IN ARRAY v_pk LOOP
      CONTINUE WHEN k = 'enterprise_id';
      v_part := CASE WHEN p_key_map ? k THEN rec.payload ->> (p_key_map ->> k)
                     WHEN k LIKE '%\_sequence' THEN '1'      -- 순번 기본키는 변환이 1 로 채운다 (gov.standardize_batch 와 같은 규칙)
                     ELSE NULL END;
      IF v_part IS NULL AND k NOT IN ('site_id', 'plant_id') THEN v_skip := true; EXIT; END IF;
      v_key := v_key || CASE WHEN v_key = '' THEN '' ELSE '|' END || coalesce(v_part, '');
    END LOOP;
    CONTINUE WHEN v_skip;
    FOR k IN SELECT * FROM jsonb_object_keys(p_attrs) LOOP
      CONTINUE WHEN rec.payload ->> k IS NULL OR rec.payload ->> k = '';
      INSERT INTO ksx.extension_attribute (enterprise_id, table_name, record_key, attr_name, attr_value, property_iri, lake_batch_id)
      VALUES (v_ent, p_table, v_key, left(k, 100), left(rec.payload ->> k, 4000), nullif(p_attrs ->> k, ''), p_batch_id)
      ON CONFLICT (enterprise_id, table_name, record_key, attr_name) DO UPDATE
         SET attr_value = EXCLUDED.attr_value, property_iri = coalesce(EXCLUDED.property_iri, ksx.extension_attribute.property_iri),
             lake_batch_id = EXCLUDED.lake_batch_id, lake_loaded_at = now();
      n := n + 1;
    END LOOP;
  END LOOP;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text, row_count)
  VALUES ('UI', 'store_extension_attributes', b.dataset_id, 'raw.ingest_batch:' || p_batch_id, 'ksx.' || p_table, n);
  RETURN jsonb_build_object('rows', n, 'columns', v_cols);
END $$;
