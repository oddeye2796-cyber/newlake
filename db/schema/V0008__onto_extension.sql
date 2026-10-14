-- V0008: 온톨로지 확장 CRUD 3차 — 회사 확장 클래스·속성·관계, 확장 제안 큐, 확장 속성 보관, 온톨로지 버전 발행, 표준 존 배치 되돌리기.
-- 표준(ksx) 클래스·속성은 읽기 전용이다. 확장은 arcon 네임스페이스에만 만든다.
-- 모든 쓰기는 SECURITY DEFINER 함수로만 하고, 함수가 역할을 다시 확인하며 감사 기록을 남긴다.

-- ── 스키마 변경 ───────────────────────────────────────────────────────────
ALTER TABLE onto.property ADD COLUMN IF NOT EXISTS domain_class_iri VARCHAR(300) REFERENCES onto.class(class_iri) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE onto.property ADD COLUMN IF NOT EXISTS unit VARCHAR(30);
ALTER TABLE onto.property ADD COLUMN IF NOT EXISTS definition_ko TEXT;
ALTER TABLE onto.link ADD COLUMN IF NOT EXISTS is_standard BOOLEAN NOT NULL DEFAULT TRUE;
CREATE UNIQUE INDEX IF NOT EXISTS ux_link_triple ON onto.link (subject_class_iri, property_iri, object_class_iri);

-- 표준 표에 자리가 없는 열의 값. 표준 행(표·키)에 붙는 확장 속성이고, 승인된 확장 속성(property_iri)과 이어진다.
CREATE TABLE IF NOT EXISTS ksx.extension_attribute (
    ext_id          BIGSERIAL PRIMARY KEY,
    enterprise_id   VARCHAR(50) NOT NULL,
    table_name      VARCHAR(63) NOT NULL,
    record_key      TEXT NOT NULL,                  -- 기본키 값을 '|' 로 이은 것 (enterprise_id 제외)
    attr_name       VARCHAR(100) NOT NULL,          -- 원천 열 이름
    attr_value      TEXT,
    property_iri    VARCHAR(300) REFERENCES onto.property(property_iri),
    lake_batch_id   UUID,
    lake_loaded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (enterprise_id, table_name, record_key, attr_name)
);
CREATE INDEX IF NOT EXISTS ix_ext_attr_batch ON ksx.extension_attribute (lake_batch_id);
CREATE INDEX IF NOT EXISTS ix_ext_attr_table ON ksx.extension_attribute (enterprise_id, table_name, attr_name);
GRANT SELECT ON ksx.extension_attribute TO lake_app, lake_agent;

-- 표준에 없는 열을 온톨로지 확장으로 올리자는 제안. 적재 때 자동으로 쌓이고 스튜어드·온톨로지 관리자가 결정한다.
CREATE TABLE IF NOT EXISTS onto.extension_proposal (
    proposal_id          BIGSERIAL PRIMARY KEY,
    enterprise_id        VARCHAR(50) NOT NULL,
    dataset_id           VARCHAR(150) NOT NULL,
    batch_id             UUID,
    std_table            VARCHAR(63),
    column_name          VARCHAR(200) NOT NULL,
    sample_values        JSONB NOT NULL DEFAULT '[]',
    profile              VARCHAR(10),
    kind                 VARCHAR(10) NOT NULL DEFAULT 'PROPERTY' CHECK (kind IN ('PROPERTY','CLASS','REF')),
    target_class_iri     VARCHAR(300) REFERENCES onto.class(class_iri),
    suggested_local_name VARCHAR(100),
    suggested_label      VARCHAR(200),
    suggested_range_iri  VARCHAR(300),
    unit                 VARCHAR(30),
    confidence           NUMERIC(4,3),
    matched_property_iri VARCHAR(300) REFERENCES onto.property(property_iri),
    rationale            TEXT,
    status               VARCHAR(10) NOT NULL DEFAULT 'PROPOSED' CHECK (status IN ('PROPOSED','ACCEPTED','REJECTED')),
    rows_seen            BIGINT NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_by           VARCHAR(50),
    decided_at           TIMESTAMPTZ,
    result_iri           VARCHAR(300),
    UNIQUE (enterprise_id, dataset_id, column_name)
);
ALTER TABLE onto.extension_proposal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS p_scope ON onto.extension_proposal;
CREATE POLICY p_scope ON onto.extension_proposal USING (gov.scope_ok(enterprise_id, NULL, NULL));
GRANT SELECT ON onto.extension_proposal TO lake_app;
GRANT SELECT ON onto.ontology_version, onto.namespace TO lake_app;

SELECT gov.apply_scope_policies();

-- ── 확장 클래스 ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.ext_iri(p_local_name text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$ SELECT 'https://ontology.impix.co.kr/arcon/' || p_local_name $$;

CREATE OR REPLACE FUNCTION gov.save_ext_class(p_local_name text, p_label_ko text, p_label_en text, p_business_group text,
                                              p_parent_class_iri text, p_definition_ko text, p_is_event boolean)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager'); v_iri text; v_std boolean;
BEGIN
  IF p_local_name !~ '^[A-Z][A-Za-z0-9]{1,79}$' THEN RAISE EXCEPTION '클래스 이름은 대문자로 시작하는 영문·숫자 2~80자여야 합니다 (예: VendorContract)'; END IF;
  IF length(btrim(coalesce(p_label_ko, ''))) = 0 THEN RAISE EXCEPTION '한글 이름이 비어 있습니다'; END IF;
  v_iri := gov.ext_iri(p_local_name);
  SELECT is_standard INTO v_std FROM onto.class WHERE class_iri = v_iri;
  IF v_std THEN RAISE EXCEPTION '% 는 표준 클래스라 고칠 수 없습니다', p_local_name; END IF;
  IF EXISTS (SELECT 1 FROM onto.class WHERE local_name = p_local_name AND is_standard) THEN
    RAISE EXCEPTION '표준 클래스 % 와 이름이 겹칩니다. 다른 이름을 쓰세요', p_local_name;
  END IF;
  IF nullif(p_parent_class_iri, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_parent_class_iri) THEN
    RAISE EXCEPTION '상위 클래스 % 가 없습니다', p_parent_class_iri;
  END IF;
  IF p_parent_class_iri = v_iri THEN RAISE EXCEPTION '자기 자신을 상위 클래스로 둘 수 없습니다'; END IF;
  INSERT INTO onto.class (class_iri, local_name, label_ko, label_en, business_group, parent_class_iri, is_event, is_standard, definition_ko)
  VALUES (v_iri, p_local_name, btrim(p_label_ko), nullif(btrim(coalesce(p_label_en, '')), ''), nullif(btrim(coalesce(p_business_group, '')), ''),
          nullif(p_parent_class_iri, ''), coalesce(p_is_event, false), false, nullif(btrim(coalesce(p_definition_ko, '')), ''))
  ON CONFLICT (class_iri) DO UPDATE
     SET label_ko = EXCLUDED.label_ko, label_en = EXCLUDED.label_en, business_group = EXCLUDED.business_group,
         parent_class_iri = EXCLUDED.parent_class_iri, is_event = EXCLUDED.is_event, definition_ko = EXCLUDED.definition_ko,
         version_id = NULL;   -- 고치면 다음 발행 때 다시 묶인다
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text)
  VALUES ('UI', 'save_ext_class', 'onto.class:' || v_iri, p_label_ko);
  RETURN v_iri;
END $$;

CREATE OR REPLACE FUNCTION gov.delete_ext_class(p_class_iri text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager'); c onto.class;
BEGIN
  SELECT * INTO c FROM onto.class WHERE class_iri = p_class_iri;
  IF NOT FOUND THEN RAISE EXCEPTION '클래스 % 가 없습니다', p_class_iri; END IF;
  IF c.is_standard THEN RAISE EXCEPTION '표준 클래스는 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM onto.class WHERE parent_class_iri = p_class_iri) THEN RAISE EXCEPTION '하위 클래스가 있어 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM catalog.dataset WHERE represents_class_iri = p_class_iri) THEN RAISE EXCEPTION '이 클래스를 표현하는 데이터셋이 있어 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM onto.property WHERE domain_class_iri = p_class_iri OR range_iri = p_class_iri) THEN RAISE EXCEPTION '이 클래스를 쓰는 속성이 있어 지울 수 없습니다. 속성을 먼저 지우세요'; END IF;
  IF EXISTS (SELECT 1 FROM onto.link WHERE subject_class_iri = p_class_iri OR object_class_iri = p_class_iri) THEN RAISE EXCEPTION '관계가 있어 지울 수 없습니다. 관계를 먼저 지우세요'; END IF;
  IF EXISTS (SELECT 1 FROM onto.action WHERE target_class_iri = p_class_iri) OR EXISTS (SELECT 1 FROM catalog.quality_rule WHERE target_class_iri = p_class_iri)
     OR EXISTS (SELECT 1 FROM gov.access_policy WHERE target_class_iri = p_class_iri) OR EXISTS (SELECT 1 FROM gov.action_policy WHERE trigger_class_iri = p_class_iri) THEN
    RAISE EXCEPTION '조치·품질 규칙·정책이 이 클래스를 가리키고 있어 지울 수 없습니다';
  END IF;
  DELETE FROM onto.class WHERE class_iri = p_class_iri;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text) VALUES ('UI', 'delete_ext_class', 'onto.class:' || p_class_iri, c.label_ko);
END $$;

-- ── 확장 속성 ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.save_ext_property(p_local_name text, p_kind text, p_label_ko text, p_domain_class_iri text,
                                                 p_range_iri text, p_unit text, p_code_scheme text, p_definition_ko text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager', 'data_steward'); v_iri text; v_std boolean; v_range text;
BEGIN
  IF p_local_name !~ '^[a-z][A-Za-z0-9]{1,79}$' THEN RAISE EXCEPTION '속성 이름은 소문자로 시작하는 영문·숫자 2~80자여야 합니다 (예: vendorName)'; END IF;
  IF p_kind NOT IN ('DATATYPE', 'OBJECT', 'CODE') THEN RAISE EXCEPTION '속성 종류는 DATATYPE·OBJECT·CODE 중 하나입니다'; END IF;
  IF length(btrim(coalesce(p_label_ko, ''))) = 0 THEN RAISE EXCEPTION '한글 이름이 비어 있습니다'; END IF;
  IF nullif(p_domain_class_iri, '') IS NULL OR NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_domain_class_iri) THEN
    RAISE EXCEPTION '속성이 붙을 클래스 % 가 없습니다', p_domain_class_iri;
  END IF;
  v_iri := gov.ext_iri(p_local_name);
  IF EXISTS (SELECT 1 FROM onto.property WHERE property_iri = v_iri AND version_id IS NOT NULL AND property_iri NOT LIKE '%/arcon/%') THEN
    RAISE EXCEPTION '% 는 표준 속성이라 고칠 수 없습니다', p_local_name;
  END IF;
  IF EXISTS (SELECT 1 FROM onto.property WHERE local_name = p_local_name AND property_iri LIKE '%/ksx9101/%') THEN
    RAISE EXCEPTION '표준 속성 % 와 이름이 겹칩니다. 다른 이름을 쓰세요', p_local_name;
  END IF;
  IF p_kind = 'OBJECT' THEN
    IF nullif(p_range_iri, '') IS NULL OR NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_range_iri) THEN
      RAISE EXCEPTION '참조 속성은 가리킬 클래스(range)가 있어야 합니다';
    END IF;
    v_range := p_range_iri;
  ELSIF p_kind = 'CODE' THEN
    v_range := 'http://www.w3.org/2004/02/skos/core#Concept';
  ELSE
    v_range := coalesce(nullif(p_range_iri, ''), 'http://www.w3.org/2001/XMLSchema#string');
    IF v_range NOT LIKE 'http://www.w3.org/2001/XMLSchema#%' THEN RAISE EXCEPTION '값 속성의 형은 xsd: 형이어야 합니다 (string·decimal·integer·date·dateTime·boolean)'; END IF;
  END IF;
  INSERT INTO onto.property (property_iri, local_name, kind, label_ko, range_iri, code_scheme, domain_class_iri, unit, definition_ko)
  VALUES (v_iri, p_local_name, p_kind, btrim(p_label_ko), v_range, CASE WHEN p_kind = 'CODE' THEN nullif(p_code_scheme, '') END,
          p_domain_class_iri, nullif(btrim(coalesce(p_unit, '')), ''), nullif(btrim(coalesce(p_definition_ko, '')), ''))
  ON CONFLICT (property_iri) DO UPDATE
     SET kind = EXCLUDED.kind, label_ko = EXCLUDED.label_ko, range_iri = EXCLUDED.range_iri, code_scheme = EXCLUDED.code_scheme,
         domain_class_iri = EXCLUDED.domain_class_iri, unit = EXCLUDED.unit, definition_ko = EXCLUDED.definition_ko, version_id = NULL;
  -- 참조 속성은 관계(link)로도 보인다
  DELETE FROM onto.link WHERE property_iri = v_iri AND NOT is_standard AND (p_kind <> 'OBJECT' OR subject_class_iri <> p_domain_class_iri OR object_class_iri <> v_range);
  IF p_kind = 'OBJECT' THEN
    INSERT INTO onto.link (subject_class_iri, property_iri, object_class_iri, relation_kind, is_standard)
    VALUES (p_domain_class_iri, v_iri, v_range, '확장 참조', false) ON CONFLICT (subject_class_iri, property_iri, object_class_iri) DO NOTHING;
  END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text) VALUES ('UI', 'save_ext_property', 'onto.property:' || v_iri, p_kind || ' ' || p_label_ko);
  RETURN v_iri;
END $$;

CREATE OR REPLACE FUNCTION gov.delete_ext_property(p_property_iri text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager', 'data_steward'); p onto.property;
BEGIN
  SELECT * INTO p FROM onto.property WHERE property_iri = p_property_iri;
  IF NOT FOUND THEN RAISE EXCEPTION '속성 % 가 없습니다', p_property_iri; END IF;
  IF p_property_iri NOT LIKE '%/arcon/%' OR p.domain_class_iri IS NULL THEN RAISE EXCEPTION '표준 속성은 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM catalog.dataset_field WHERE maps_to_property_iri = p_property_iri) THEN RAISE EXCEPTION '이 속성에 매핑된 필드가 있어 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM ksx.extension_attribute WHERE property_iri = p_property_iri) THEN RAISE EXCEPTION '이 속성으로 보관된 확장 값이 있어 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM onto.action WHERE sets_property_iri = p_property_iri) OR EXISTS (SELECT 1 FROM onto.property WHERE super_property_iri = p_property_iri) THEN
    RAISE EXCEPTION '조치나 하위 속성이 이 속성을 쓰고 있어 지울 수 없습니다';
  END IF;
  IF EXISTS (SELECT 1 FROM onto.link WHERE property_iri = p_property_iri AND is_standard) THEN RAISE EXCEPTION '표준 관계가 이 속성을 쓰고 있어 지울 수 없습니다'; END IF;
  DELETE FROM onto.link WHERE property_iri = p_property_iri;
  UPDATE onto.extension_proposal SET matched_property_iri = NULL WHERE matched_property_iri = p_property_iri;
  DELETE FROM onto.property WHERE property_iri = p_property_iri;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text) VALUES ('UI', 'delete_ext_property', 'onto.property:' || p_property_iri, p.label_ko);
END $$;

-- ── 확장 관계 ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION gov.save_ext_link(p_subject_class_iri text, p_property_iri text, p_object_class_iri text, p_relation_kind text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager'); v_id bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_subject_class_iri) THEN RAISE EXCEPTION '주어 클래스 % 가 없습니다', p_subject_class_iri; END IF;
  IF NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri = p_object_class_iri) THEN RAISE EXCEPTION '목적 클래스 % 가 없습니다', p_object_class_iri; END IF;
  IF NOT EXISTS (SELECT 1 FROM onto.property WHERE property_iri = p_property_iri AND kind = 'OBJECT') THEN RAISE EXCEPTION '참조 속성 % 가 없습니다', p_property_iri; END IF;
  IF p_property_iri NOT LIKE '%/arcon/%' AND NOT EXISTS (SELECT 1 FROM onto.class WHERE class_iri IN (p_subject_class_iri, p_object_class_iri) AND NOT is_standard) THEN
    RAISE EXCEPTION '표준 클래스끼리는 표준 속성으로 관계를 더할 수 없습니다. 확장 속성을 쓰세요';
  END IF;
  INSERT INTO onto.link (subject_class_iri, property_iri, object_class_iri, relation_kind, is_standard)
  VALUES (p_subject_class_iri, p_property_iri, p_object_class_iri, coalesce(nullif(btrim(coalesce(p_relation_kind, '')), ''), '확장 참조'), false)
  ON CONFLICT (subject_class_iri, property_iri, object_class_iri) DO UPDATE SET relation_kind = EXCLUDED.relation_kind
  RETURNING link_id INTO v_id;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text) VALUES ('UI', 'save_ext_link', 'onto.link:' || v_id, p_subject_class_iri || ' → ' || p_object_class_iri);
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION gov.delete_ext_link(p_link_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager'); l onto.link;
BEGIN
  SELECT * INTO l FROM onto.link WHERE link_id = p_link_id;
  IF NOT FOUND THEN RAISE EXCEPTION '관계 % 가 없습니다', p_link_id; END IF;
  IF l.is_standard THEN RAISE EXCEPTION '표준 관계는 지울 수 없습니다'; END IF;
  DELETE FROM onto.link WHERE link_id = p_link_id;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text) VALUES ('UI', 'delete_ext_link', 'onto.link:' || p_link_id, l.subject_class_iri || ' → ' || l.object_class_iri);
END $$;

-- ── 온톨로지 버전 발행 ────────────────────────────────────────────────────
-- 아직 버전에 묶이지 않은(고친) 확장 클래스·속성을 새 arcon 버전으로 묶는다. 이전 RELEASED arcon 버전은 RETIRED.
CREATE OR REPLACE FUNCTION gov.publish_ontology_version(p_version_info text, p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager'); v_id text; n_c int; n_p int;
BEGIN
  IF length(btrim(coalesce(p_version_info, ''))) = 0 THEN RAISE EXCEPTION '버전 표시가 비어 있습니다 (예: 1.1)'; END IF;
  v_id := 'arcon-' || regexp_replace(btrim(p_version_info), '[^A-Za-z0-9.]+', '-', 'g') || '-' || to_char(now(), 'YYYYMMDD-HH24MI');
  IF NOT EXISTS (SELECT 1 FROM onto.class WHERE NOT is_standard AND version_id IS NULL)
     AND NOT EXISTS (SELECT 1 FROM onto.property WHERE property_iri LIKE '%/arcon/%' AND version_id IS NULL) THEN
    RAISE EXCEPTION '발행할 변경이 없습니다. 확장 클래스·속성을 먼저 고치거나 더하세요';
  END IF;
  UPDATE onto.ontology_version SET status = 'RETIRED' WHERE ontology_iri = 'https://ontology.impix.co.kr/arcon' AND status = 'RELEASED';
  INSERT INTO onto.ontology_version (version_id, ontology_iri, version_info, source, status, validated_at, released_at)
  VALUES (v_id, 'https://ontology.impix.co.kr/arcon', btrim(p_version_info), coalesce(nullif(btrim(coalesce(p_note, '')), ''), '관리 화면 발행'), 'RELEASED', now(), now());
  UPDATE onto.class SET version_id = v_id WHERE NOT is_standard AND version_id IS NULL;
  GET DIAGNOSTICS n_c = ROW_COUNT;
  UPDATE onto.property SET version_id = v_id WHERE property_iri LIKE '%/arcon/%' AND version_id IS NULL;
  GET DIAGNOSTICS n_p = ROW_COUNT;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text, row_count)
  VALUES ('UI', 'publish_ontology_version', 'onto.ontology_version:' || v_id, p_version_info, n_c + n_p);
  RETURN jsonb_build_object('version_id', v_id, 'classes', n_c, 'properties', n_p);
END $$;

-- ── 확장 속성 보관 (적재 때 표준 표에 자리 없는 열) ───────────────────────
-- p_key_map: {표준 키 열: 원천 열}, p_attrs: {원천 열: 확장 속성 IRI 또는 null}
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
      v_part := CASE WHEN p_key_map ? k THEN rec.payload ->> (p_key_map ->> k) ELSE NULL END;
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

-- ── 확장 제안 큐 ──────────────────────────────────────────────────────────
-- p_items: [{column_name, sample_values, profile, kind, target_class_iri, suggested_local_name, suggested_label, suggested_range_iri, unit, confidence, matched_property_iri, rationale, rows_seen}]
CREATE OR REPLACE FUNCTION gov.propose_extensions(p_batch_id uuid, p_items jsonb)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role(); b raw.ingest_batch; x jsonb; n int := 0;
BEGIN
  SELECT * INTO b FROM raw.ingest_batch WHERE batch_id = p_batch_id;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  FOR x IN SELECT * FROM jsonb_array_elements(coalesce(p_items, '[]')) LOOP
    -- 이미 결정된 열은 다시 묻지 않는다
    CONTINUE WHEN EXISTS (SELECT 1 FROM onto.extension_proposal WHERE enterprise_id = v_ent AND dataset_id = b.dataset_id AND column_name = x ->> 'column_name' AND status <> 'PROPOSED');
    INSERT INTO onto.extension_proposal (enterprise_id, dataset_id, batch_id, std_table, column_name, sample_values, profile, kind, target_class_iri,
                                         suggested_local_name, suggested_label, suggested_range_iri, unit, confidence, matched_property_iri, rationale, rows_seen)
    VALUES (v_ent, b.dataset_id, p_batch_id, replace(b.std_table, 'ksx.', ''), left(x ->> 'column_name', 200), coalesce(x -> 'sample_values', '[]'), x ->> 'profile',
            coalesce(x ->> 'kind', 'PROPERTY'), nullif(x ->> 'target_class_iri', ''), nullif(x ->> 'suggested_local_name', ''), nullif(x ->> 'suggested_label', ''),
            nullif(x ->> 'suggested_range_iri', ''), nullif(x ->> 'unit', ''), (x ->> 'confidence')::numeric, nullif(x ->> 'matched_property_iri', ''), x ->> 'rationale',
            coalesce((x ->> 'rows_seen')::bigint, 0))
    ON CONFLICT (enterprise_id, dataset_id, column_name) DO UPDATE
       SET batch_id = EXCLUDED.batch_id, std_table = EXCLUDED.std_table, sample_values = EXCLUDED.sample_values, profile = EXCLUDED.profile, kind = EXCLUDED.kind,
           target_class_iri = EXCLUDED.target_class_iri, suggested_local_name = EXCLUDED.suggested_local_name, suggested_label = EXCLUDED.suggested_label,
           suggested_range_iri = EXCLUDED.suggested_range_iri, unit = EXCLUDED.unit, confidence = EXCLUDED.confidence,
           matched_property_iri = EXCLUDED.matched_property_iri, rationale = EXCLUDED.rationale, rows_seen = EXCLUDED.rows_seen, created_at = now();
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

-- 결정. 승인하면 확장 속성(또는 클래스)을 만들고, 이미 보관된 확장 값에 속성을 이어 준다.
CREATE OR REPLACE FUNCTION gov.decide_extension_proposal(p_proposal_id bigint, p_accept boolean, p_local_name text, p_label_ko text,
                                                         p_target_class_iri text, p_range_iri text, p_unit text, p_kind text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE
  v_ent text := gov.require_role('ontology_manager', 'data_steward');
  v_user text := current_setting('app.user_id', true);
  p onto.extension_proposal; v_iri text; v_kind text; v_table text;
BEGIN
  SELECT * INTO p FROM onto.extension_proposal WHERE proposal_id = p_proposal_id AND enterprise_id = v_ent FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '제안 % 가 없습니다', p_proposal_id; END IF;
  IF p.status <> 'PROPOSED' THEN RAISE EXCEPTION '이미 결정된 제안입니다 (%)', p.status; END IF;
  IF NOT p_accept THEN
    UPDATE onto.extension_proposal SET status = 'REJECTED', decided_by = v_user, decided_at = now() WHERE proposal_id = p_proposal_id;
    INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text) VALUES ('UI', 'reject_extension', p.dataset_id, 'onto.extension_proposal:' || p_proposal_id, p.column_name);
    RETURN jsonb_build_object('status', 'REJECTED');
  END IF;
  v_kind := coalesce(nullif(p_kind, ''), p.kind);
  IF v_kind = 'CLASS' THEN
    v_iri := gov.save_ext_class(coalesce(nullif(p_local_name, ''), p.suggested_local_name), coalesce(nullif(p_label_ko, ''), p.suggested_label, p.column_name),
                                NULL, NULL, nullif(p_target_class_iri, ''), '확장 제안 ' || p_proposal_id || ' 에서 승인 (원천 열 ' || p.column_name || ')', false);
  ELSIF p.matched_property_iri IS NOT NULL AND nullif(p_local_name, '') IS NULL THEN
    v_iri := p.matched_property_iri;   -- 이미 있는 확장 속성에 잇기만 한다
  ELSE
    v_iri := gov.save_ext_property(coalesce(nullif(p_local_name, ''), p.suggested_local_name), CASE WHEN v_kind = 'REF' THEN 'OBJECT' ELSE 'DATATYPE' END,
                                   coalesce(nullif(p_label_ko, ''), p.suggested_label, p.column_name), coalesce(nullif(p_target_class_iri, ''), p.target_class_iri),
                                   coalesce(nullif(p_range_iri, ''), p.suggested_range_iri), coalesce(nullif(p_unit, ''), p.unit), NULL,
                                   '확장 제안 ' || p_proposal_id || ' 에서 승인 (원천 열 ' || p.column_name || ')');
  END IF;
  IF v_kind <> 'CLASS' AND p.std_table IS NOT NULL THEN
    UPDATE ksx.extension_attribute SET property_iri = v_iri WHERE enterprise_id = v_ent AND table_name = p.std_table AND attr_name = p.column_name AND property_iri IS NULL;
  END IF;
  UPDATE onto.extension_proposal SET status = 'ACCEPTED', decided_by = v_user, decided_at = now(), result_iri = v_iri, matched_property_iri = CASE WHEN v_kind = 'CLASS' THEN matched_property_iri ELSE v_iri END
   WHERE proposal_id = p_proposal_id;
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text) VALUES ('UI', 'accept_extension', p.dataset_id, 'onto.extension_proposal:' || p_proposal_id, p.column_name || ' → ' || v_iri);
  RETURN jsonb_build_object('status', 'ACCEPTED', 'result_iri', v_iri);
END $$;

-- ── 표준 존 배치 되돌리기 ─────────────────────────────────────────────────
-- 이 배치로 들어간 표준 행(lake_batch_id)과 확장 값을 지우고 배치를 원천 존 상태(LANDED)로 되돌린다.
-- 뒤 배치가 같은 키를 덮어쓴 행은 lake_batch_id 가 바뀌어 있어 남는다.
CREATE OR REPLACE FUNCTION gov.rollback_batch(p_batch_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role(); b raw.ingest_batch; n bigint := 0; n_ext bigint := 0; v_std text;
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
  SELECT dataset_id INTO v_std FROM catalog.dataset WHERE location_uri = 'postgresql://lake/' || b.std_table LIMIT 1;
  UPDATE raw.ingest_batch SET status = 'LANDED', std_table = NULL, std_job_run_id = NULL WHERE batch_id = p_batch_id;
  INSERT INTO catalog.job_run (pipeline_id, status, rows_in, rows_out, rows_rejected, ended_at, enterprise_id, code_version)
  VALUES ('p-console-std', 'SUCCESS', n, 0, 0, now(), v_ent, 'console-rollback');
  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text, row_count)
  VALUES ('UI', 'rollback_batch', b.dataset_id, 'raw.ingest_batch:' || p_batch_id, b.std_table, n);
  RETURN jsonb_build_object('batch_id', p_batch_id, 'table', b.std_table, 'std_dataset_id', v_std, 'rows', n, 'extension_rows', n_ext);
END $$;

-- 버전 지우기: 클래스·속성이 하나도 안 담긴(모두 지워진) 버전만. 현재 발행본을 지우면 직전 발행본이 다시 현재 버전이 된다.
CREATE OR REPLACE FUNCTION gov.delete_ontology_version(p_version_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_role('ontology_manager'); v onto.ontology_version; v_prev text;
BEGIN
  SELECT * INTO v FROM onto.ontology_version WHERE version_id = p_version_id;
  IF NOT FOUND THEN RAISE EXCEPTION '버전 % 가 없습니다', p_version_id; END IF;
  IF v.ontology_iri NOT LIKE '%/arcon%' THEN RAISE EXCEPTION '표준 코어 버전은 지울 수 없습니다'; END IF;
  IF EXISTS (SELECT 1 FROM onto.class WHERE version_id = p_version_id) OR EXISTS (SELECT 1 FROM onto.property WHERE version_id = p_version_id) THEN
    RAISE EXCEPTION '버전 % 에 담긴 클래스·속성이 있어 지울 수 없습니다', p_version_id;
  END IF;
  DELETE FROM onto.ontology_version WHERE version_id = p_version_id;
  IF v.status = 'RELEASED' THEN
    SELECT version_id INTO v_prev FROM onto.ontology_version WHERE ontology_iri = v.ontology_iri AND status = 'RETIRED' ORDER BY released_at DESC NULLS LAST, version_id DESC LIMIT 1;
    IF v_prev IS NOT NULL THEN UPDATE onto.ontology_version SET status = 'RELEASED' WHERE version_id = v_prev; END IF;
  END IF;
  INSERT INTO gov.audit_log (channel, action, object_ref, query_text) VALUES ('UI', 'delete_ontology_version', 'onto.ontology_version:' || p_version_id, v.version_info);
END $$;

REVOKE ALL ON FUNCTION gov.ext_iri(text), gov.save_ext_class(text, text, text, text, text, text, boolean), gov.delete_ext_class(text),
  gov.save_ext_property(text, text, text, text, text, text, text, text), gov.delete_ext_property(text),
  gov.save_ext_link(text, text, text, text), gov.delete_ext_link(bigint), gov.publish_ontology_version(text, text),
  gov.store_extension_attributes(uuid, text, jsonb, jsonb), gov.propose_extensions(uuid, jsonb),
  gov.decide_extension_proposal(bigint, boolean, text, text, text, text, text, text), gov.rollback_batch(uuid), gov.delete_ontology_version(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.ext_iri(text), gov.save_ext_class(text, text, text, text, text, text, boolean), gov.delete_ext_class(text),
  gov.save_ext_property(text, text, text, text, text, text, text, text), gov.delete_ext_property(text),
  gov.save_ext_link(text, text, text, text), gov.delete_ext_link(bigint), gov.publish_ontology_version(text, text),
  gov.store_extension_attributes(uuid, text, jsonb, jsonb), gov.propose_extensions(uuid, jsonb),
  gov.decide_extension_proposal(bigint, boolean, text, text, text, text, text, text), gov.rollback_batch(uuid), gov.delete_ontology_version(text) TO lake_app;

-- ── 적재 시 자동 품질 검증용 기본 검사식 규칙 (켜진 SQL 규칙은 표준 존 변환 직후 자동으로 돈다) ──
INSERT INTO catalog.quality_rule (rule_id, label_ko, dimension, target_class_iri, sql_check, severity, threshold, enabled) VALUES
 ('po-quantity-positive', '발주 수량은 0보다 커야 함', '값', 'https://ontology.impix.co.kr/ksx9101/PurchaseOrder',
  'SELECT purchase_order_id AS focus_node, ''purchase_order_quantity'' AS result_path, ''발주 수량이 0 이하: '' || coalesce(purchase_order_quantity::text, ''없음'') AS message FROM ksx.purchase_order WHERE purchase_order_quantity IS NULL OR purchase_order_quantity <= 0',
  'Violation', 99.0, true),
 ('po-item-known', '발주 품목은 품목 마스터에 있어야 함', '관계', 'https://ontology.impix.co.kr/ksx9101/PurchaseOrder',
  'SELECT p.purchase_order_id AS focus_node, ''item_id'' AS result_path, ''품목 '' || p.item_id || '' 이 품목 마스터에 없음'' AS message FROM ksx.purchase_order p LEFT JOIN ksx.item_master i ON i.enterprise_id = p.enterprise_id AND i.item_id = p.item_id WHERE p.item_id IS NOT NULL AND i.item_id IS NULL',
  'Violation', 100.0, true),
 ('lot-quantity-consistent', '로트 생산 수량은 생성 수량을 넘을 수 없음', '일관성', 'https://ontology.impix.co.kr/ksx9101/Lot',
  'SELECT lot_id AS focus_node, ''produced_quantity'' AS result_path, ''생산 '' || produced_quantity || '' > 생성 '' || lot_created_quantity AS message FROM ksx.lot WHERE produced_quantity > lot_created_quantity',
  'Warning', 95.0, true)
ON CONFLICT (rule_id) DO NOTHING;
