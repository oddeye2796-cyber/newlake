-- V0014 · KS X 9101-1:2025 개정(안) v1.0 최종본(온톨로지용) 반영
--   이 파일은 tools/gen_schema.py 가 tools/V0014.template.sql 에 생성 조각을 채워 만든다. 적용 후에는 고치지 말 것.
--
-- 표준에서 바뀐 것 (테이블정의서 '표준 검토사항' 17건 모두 반영본)
--   1) 헤더·라인 구조(7.1): 단위그룹·자재명세서·공정경로·창고·수주오더·구매발주·출하의뢰·배송 8개 명사를 ○○헤더 + ○○라인 2개 표로.
--      수주오더식별자·구매발주식별자는 없어지고 문서번호(헤더) + 순번(라인)이 식별 키. 표준 외 보조 테이블(BOMHeader 등)은 표준 헤더가 됐다.
--   2) 새 명사 배송(Delivery) — 배송헤더·배송라인. 명사 67 → 68, 테이블 70 → 76.
--   3) 이벤트·보고 명사 9개(착공·완공·운행시작·운행완료·운송위치·설비상태·알람·설비파라미터이력·고객제품데이터)에 식별자(ID) 속성 추가.
--   4) 협력업체품질검사계획·신청은 구매발주식별자 대신 구매문서번호+순번으로 구매발주라인을 참조. 자재명세서라인에 라인순번 추가.
--   5) 투입인력 실투입시간은 기간(INTERVAL) → 숫자(단위코드와 함께), 투입품목 창고섹션은 문자열(255).
--   6) 모든 표에 행 일련번호(○○SequenceNo) — 레이크에서는 <표>_sequence_no (자동 증가·고유). 기본키는 계속 식별 키(업무 키).
--   7) 공통코드: 운송수단코드(TransportationMethodCode) 그룹 7개 코드 추가 (온톨로지 코드리스트에 반영).
--
-- 현장마다 다른 파일은 지금처럼 한 번에 넣는다: 라인 표로 넣으면 같은 파일의 헤더 열(거래처·발주일 등)로 헤더 행을 함께 채운다.
-- 원천에 새 식별자 열이 없으면 예전 키 조합(gov.ksx_natural_key)으로 식별자를 만든다.

SET client_min_messages = warning;
SET CONSTRAINTS ALL DEFERRED;

-- ── 0) 목표 명세 ───────────────────────────────────────────────────────────
-- @@SPEC@@

-- 이름이 바뀌는 표 (예전 → 새)
CREATE TEMP TABLE ksx_rename (old text PRIMARY KEY, new text NOT NULL) ON COMMIT DROP;
INSERT INTO ksx_rename VALUES
  ('sales_order', 'sales_order_line'), ('purchase_order', 'purchase_order_line'), ('uom_group', 'uom_group_line'),
  ('bom', 'bom_line'), ('routing', 'routing_line'), ('product_release_request', 'product_release_request_line'),
  ('warehouse_location', 'warehouse_location_header');
-- 헤더 ← 라인 (라인 행에서 헤더 행을 만든다). 창고는 예전 표가 헤더가 되고 섹션 목록을 라인으로 푼다.
CREATE TEMP TABLE ksx_header_line (header text PRIMARY KEY, line text NOT NULL, key text[] NOT NULL) ON COMMIT DROP;
INSERT INTO ksx_header_line VALUES
  ('uom_group_header', 'uom_group_line', ARRAY['uom_group_id']),
  ('bom_header', 'bom_line', ARRAY['bom_id', 'bom_revision_number']),
  ('routing_header', 'routing_line', ARRAY['routing_id']),
  ('sales_order_header', 'sales_order_line', ARRAY['sales_document_number']),
  ('purchase_order_header', 'purchase_order_line', ARRAY['purchase_document_number']),
  ('product_release_request_header', 'product_release_request_line', ARRAY['product_release_request_id']),
  ('delivery_header', 'delivery_line', ARRAY['delivery_id']);

-- 원천에 식별자가 없을 때 식별자를 만드는 예전 키 조합 (회사 제외). gov.auto_key_columns 가 읽는다.
CREATE TABLE IF NOT EXISTS gov.ksx_natural_key (
    table_name  TEXT PRIMARY KEY,          -- ksx 표 이름
    id_column   TEXT NOT NULL,             -- 채울 식별자 열
    parts       TEXT[] NOT NULL            -- 이어 붙일 열 (값을 '-' 로 잇고 50자에서 자른다)
);
COMMENT ON TABLE gov.ksx_natural_key IS '표준 식별자가 원천에 없을 때 식별자를 만드는 자연 키 (KS X 9101 v1.0 최종본에서 식별자가 생긴 이벤트 명사)';
INSERT INTO gov.ksx_natural_key VALUES
  ('operation_start', 'operation_start_id', ARRAY['lot_id', 'operation_id', 'operation_start_time']),
  ('operation_end', 'operation_end_id', ARRAY['lot_id', 'operation_id', 'operation_end_time']),
  ('transfer_start', 'transfer_start_id', ARRAY['transfer_command_id']),
  ('transfer_end', 'transfer_end_id', ARRAY['transfer_command_id']),
  ('in_transit_location', 'in_transit_location_id', ARRAY['transfer_command_id', 'current_location']),
  ('equipment_state', 'equipment_state_id', ARRAY['equipment_id']),
  ('alarm', 'alarm_id', ARRAY['equipment_id', 'event_date_time', 'error_code']),
  ('trace_parameter', 'trace_parameter_id', ARRAY['equipment_id', 'parameter_id', 'event_date_time']),
  ('product_trace_parameter_on_customer', 'product_trace_parameter_on_customer_id',
   ARRAY['item_id', 'serial_number', 'parameter_name', 'collection_date_time'])
ON CONFLICT (table_name) DO UPDATE SET id_column = EXCLUDED.id_column, parts = EXCLUDED.parts;
GRANT SELECT ON gov.ksx_natural_key TO lake_app, lake_loader;

-- ── 1) 키·열을 바꾸기 전에 걷어낼 것: 뷰, 표준 존 FK·FK 인덱스 ──────────────
DROP VIEW IF EXISTS mart.v_otd_risk_candidate;
DROP VIEW IF EXISTS mart.v_kpi_otd;
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.conrelid::regclass AS rel, c.conname FROM pg_constraint c
            WHERE c.contype = 'f' AND c.connamespace = 'ksx'::regnamespace AND c.conname LIKE 'fk\_%'
              AND NOT EXISTS (SELECT 1 FROM pg_class p WHERE p.oid = c.conrelid AND p.relispartition) LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.rel, r.conname);
  END LOOP;
  FOR r IN SELECT i.indexrelid::regclass AS idx FROM pg_index i JOIN pg_class x ON x.oid = i.indexrelid
            WHERE x.relnamespace = 'ksx'::regnamespace AND x.relname ~ '^ix_.*_[0-9]{2}$' AND NOT i.indisprimary AND NOT i.indisunique
              AND NOT EXISTS (SELECT 1 FROM pg_inherits h WHERE h.inhrelid = i.indexrelid) LOOP
    EXECUTE format('DROP INDEX %s', r.idx);
  END LOOP;
END $$;

-- ── 2) 표 이름 바꾸기, 예전 키 기억 ─────────────────────────────────────────
-- 수주 식별자 → 수주문서번호 대응 (리스크 이벤트·시연 시드의 주문 번호를 옮길 때 쓴다)
CREATE TEMP TABLE so_id_map ON COMMIT DROP AS
  SELECT enterprise_id, sales_order_id, coalesce(sales_document_number, sales_order_id) AS docno FROM ksx.sales_order;
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM ksx_rename LOOP
    EXECUTE format('ALTER TABLE ksx.%I RENAME TO %I', r.old, r.new);
  END LOOP;
END $$;
UPDATE ksx.extension_attribute e SET table_name = r.new FROM ksx_rename r WHERE e.table_name = r.old;
UPDATE raw.ingest_batch b SET std_table = 'ksx.' || r.new FROM ksx_rename r WHERE b.std_table = 'ksx.' || r.old;
UPDATE onto.extension_proposal x SET std_table = r.new FROM ksx_rename r WHERE x.std_table = r.old;
UPDATE raw.std_preimage p SET table_name = 'ksx.' || r.new FROM ksx_rename r WHERE p.table_name = 'ksx.' || r.old;

CREATE TEMP TABLE ksx_old_pk ON COMMIT DROP AS
  SELECT c.relname::text AS tbl,
         ARRAY(SELECT a.attname::text FROM unnest(i.indkey) WITH ORDINALITY k(n, o)
                 JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.n ORDER BY k.o) AS cols
    FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid
   WHERE c.relnamespace = 'ksx'::regnamespace AND i.indisprimary AND NOT c.relispartition;

-- ── 3) 새 표 만들기 (명세에 있고 DB 에 없는 표: 헤더 4개·라인 2개·배송) ─────────
DO $$
DECLARE t record; v_cols text;
BEGIN
  FOR t IN SELECT s.* FROM ksx_spec_table s WHERE to_regclass('ksx.' || s.tbl) IS NULL LOOP
    SELECT string_agg(format('%I %s%s', c.col, c.typ, CASE WHEN c.req THEN ' NOT NULL' ELSE '' END), ', ' ORDER BY c.ord)
      INTO v_cols FROM ksx_spec_col c WHERE c.tbl = t.tbl;
    EXECUTE format('CREATE TABLE ksx.%I (%s, lake_batch_id UUID, lake_source_system VARCHAR(50), '
                   'lake_loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(), lake_record_hash CHAR(64), '
                   'lake_shacl_status VARCHAR(10) NOT NULL DEFAULT ''PENDING'' CHECK (lake_shacl_status IN (''PENDING'',''CONFORMS'',''VIOLATION'')), '
                   'CONSTRAINT %I PRIMARY KEY (%s))',
                   t.tbl, v_cols, 'pk_' || t.tbl, (SELECT string_agg(format('%I', x), ', ') FROM unnest(t.pk) x));
  END LOOP;
END $$;

-- ── 4) 있는 표에 없는 열 더하기 (일단 NULL 허용) ───────────────────────────
DO $$
DECLARE c record;
BEGIN
  FOR c IN SELECT s.* FROM ksx_spec_col s
            WHERE NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = to_regclass('ksx.' || s.tbl) AND a.attname = s.col AND NOT a.attisdropped)
            ORDER BY s.tbl, s.ord LOOP
    EXECUTE format('ALTER TABLE ksx.%I ADD COLUMN %I %s', c.tbl, c.col, c.typ);
  END LOOP;
END $$;

-- ── 5) 데이터 옮기기 ───────────────────────────────────────────────────────
-- 5-1) 예전 수주·구매발주 행에 문서번호·순번이 비어 있으면 예전 식별자로 채운다 (새 식별 키)
UPDATE ksx.sales_order_line SET sales_document_number = coalesce(sales_document_number, sales_order_id),
       sales_document_sequence = coalesce(sales_document_sequence, 1)
 WHERE sales_document_number IS NULL OR sales_document_sequence IS NULL;
UPDATE ksx.purchase_order_line SET purchase_document_number = coalesce(purchase_document_number, purchase_order_id),
       purchase_document_sequence = coalesce(purchase_document_sequence, 1)
 WHERE purchase_document_number IS NULL OR purchase_document_sequence IS NULL;
-- 5-2) 자재명세서라인 순번: 같은 자재명세서(식별자+버전) 안에서 자품목 순으로 1,2,3…
UPDATE ksx.bom_line b SET bom_line_sequence = x.rn
  FROM (SELECT ctid AS id, row_number() OVER (PARTITION BY enterprise_id, bom_id, bom_revision_number
                                              ORDER BY child_item_id, operation_sequence NULLS LAST) AS rn FROM ksx.bom_line) x
 WHERE b.ctid = x.id AND b.bom_line_sequence IS NULL;
-- 5-3) 헤더 ← 라인: 문서마다 첫 라인의 헤더 열 값으로 헤더 행을 만들고, 이미 있던 헤더(BOM·공정경로·출하의뢰)는 빈 열만 채운다
DO $$
DECLARE h record; v_cols text[]; v_upd text;
BEGIN
  FOR h IN SELECT * FROM ksx_header_line LOOP
    v_cols := ARRAY(SELECT a.attname::text FROM pg_attribute a
                     WHERE a.attrelid = ('ksx.' || h.header)::regclass AND a.attnum > 0 AND NOT a.attisdropped
                       AND a.attname NOT LIKE '%\_sequence\_no' AND a.attname <> 'lake_record_hash'
                       AND EXISTS (SELECT 1 FROM pg_attribute b WHERE b.attrelid = ('ksx.' || h.line)::regclass
                                     AND b.attname = a.attname AND NOT b.attisdropped)
                     ORDER BY a.attnum);
    SELECT string_agg(format('%1$I = coalesce(t.%1$I, EXCLUDED.%1$I)', c), ', ') INTO v_upd
      FROM unnest(v_cols) c WHERE NOT c = ANY (h.key || ARRAY['enterprise_id']);
    EXECUTE format('INSERT INTO ksx.%1$I AS t (%2$s) SELECT DISTINCT ON (enterprise_id, %3$s) %2$s FROM ksx.%4$I '
                   ' WHERE %5$s ORDER BY enterprise_id, %3$s, lake_loaded_at ON CONFLICT (enterprise_id, %3$s) DO %6$s',
                   h.header, (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_cols) c),
                   (SELECT string_agg(format('%I', c), ', ') FROM unnest(h.key) c), h.line,
                   (SELECT string_agg(format('%I IS NOT NULL', c), ' AND ') FROM unnest(h.key) c),
                   CASE WHEN v_upd IS NULL THEN 'NOTHING' ELSE 'UPDATE SET ' || v_upd END);
  END LOOP;
END $$;
-- 5-4) 창고 섹션 목록(쉼표·세미콜론·줄바꿈 구분 문자열) → 창고라인 행
INSERT INTO ksx.warehouse_location_line (enterprise_id, site_id, plant_id, creator_id, creation_date_time, modifier_id, modification_date_time,
                                         warehouse_id, warehouse_section, lake_batch_id, lake_source_system, lake_loaded_at)
SELECT DISTINCT ON (w.enterprise_id, w.warehouse_id, left(btrim(s), 255))
       w.enterprise_id, w.site_id, w.plant_id, w.creator_id, w.creation_date_time, w.modifier_id, w.modification_date_time,
       w.warehouse_id, left(btrim(s), 255), w.lake_batch_id, w.lake_source_system, w.lake_loaded_at
  FROM ksx.warehouse_location_header w
  CROSS JOIN LATERAL regexp_split_to_table(coalesce(w.warehouse_section_list, ''), '\s*[,;\n]\s*') s
 WHERE btrim(s) <> ''
ON CONFLICT DO NOTHING;
-- 5-5) 협력업체품질검사계획·신청: 구매발주식별자 → 구매문서번호 + 순번
UPDATE ksx.supplier_inspection_plan s SET purchase_document_number = p.purchase_document_number, purchase_document_sequence = p.purchase_document_sequence
  FROM ksx.purchase_order_line p WHERE p.enterprise_id = s.enterprise_id AND p.purchase_order_id = s.purchase_order_id AND s.purchase_document_number IS NULL;
UPDATE ksx.supplier_inspection_application s SET purchase_document_number = p.purchase_document_number, purchase_document_sequence = p.purchase_document_sequence
  FROM ksx.purchase_order_line p WHERE p.enterprise_id = s.enterprise_id AND p.purchase_order_id = s.purchase_order_id AND s.purchase_document_number IS NULL;
-- 5-6) 새 식별자: 이미 들어 있는 이벤트 행은 예전 키 값을 '-' 로 이어 식별자로 쓴다 (적재 때 자동 생성과 같은 규칙)
DO $$
DECLARE k record;
BEGIN
  FOR k IN SELECT * FROM gov.ksx_natural_key LOOP
    EXECUTE format('UPDATE ksx.%I SET %I = left(concat_ws(''-'', %s), 50) WHERE %I IS NULL', k.table_name, k.id_column,
                   (SELECT string_agg(format('%I::text', p), ', ') FROM unnest(k.parts) p), k.id_column);
  END LOOP;
END $$;
-- 5-7) 실투입시간: 기간 → 숫자(분). 단위코드가 비어 있으면 MIN 을 적는다
DO $$
BEGIN
  IF (SELECT format_type(atttypid, atttypmod) FROM pg_attribute WHERE attrelid = 'ksx.production_performance_personnel'::regclass
        AND attname = 'actual_labor_time') = 'interval' THEN
    UPDATE ksx.production_performance_personnel SET actual_labor_time_uom_code = 'MIN'
     WHERE actual_labor_time IS NOT NULL AND actual_labor_time_uom_code IS NULL;
    ALTER TABLE ksx.production_performance_personnel
      ALTER COLUMN actual_labor_time TYPE NUMERIC(18,6) USING round((extract(epoch FROM actual_labor_time) / 60)::numeric, 6);
  END IF;
END $$;
-- 5-8) 확장 속성의 행 키: 기본키가 바뀌는 표는 새 키 값으로 다시 적는다 (store_extension_attributes 와 같은 '|' 잇기)
DO $$
DECLARE t record; v_old text; v_new text;
BEGIN
  FOR t IN SELECT s.tbl, s.pk, o.cols AS old_pk FROM ksx_spec_table s JOIN ksx_old_pk o ON o.tbl = s.tbl
            WHERE o.cols IS DISTINCT FROM s.pk AND EXISTS (SELECT 1 FROM ksx.extension_attribute e WHERE e.table_name = s.tbl) LOOP
    SELECT string_agg(format('coalesce(x.%I::text, '''')', c), ' || ''|'' || ') INTO v_old FROM unnest(t.old_pk) c WHERE c <> 'enterprise_id';
    SELECT string_agg(format('coalesce(x.%I::text, '''')', c), ' || ''|'' || ') INTO v_new FROM unnest(t.pk) c WHERE c <> 'enterprise_id';
    EXECUTE format('UPDATE ksx.extension_attribute e SET record_key = %s FROM ksx.%I x '
                   ' WHERE e.table_name = %L AND e.enterprise_id = x.enterprise_id AND e.record_key = %s',
                   v_new, t.tbl, t.tbl, v_old);
  END LOOP;
END $$;

-- ── 6) 기본키 = 식별 키 (명세와 다르면 다시 건다). 같은 열의 예전 대체키(uk_…_doc)는 겹치므로 지운다 ──
DO $$
DECLARE t record; v_pk text; v_cur text[]; u record;
BEGIN
  FOR t IN SELECT * FROM ksx_spec_table LOOP
    SELECT c.conname, ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(n, o)
                              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.n ORDER BY k.o)
      INTO v_pk, v_cur FROM pg_constraint c WHERE c.conrelid = ('ksx.' || t.tbl)::regclass AND c.contype = 'p';
    FOR u IN SELECT c.conname FROM pg_constraint c WHERE c.conrelid = ('ksx.' || t.tbl)::regclass AND c.contype = 'u' LOOP
      EXECUTE format('ALTER TABLE ksx.%I DROP CONSTRAINT %I', t.tbl, u.conname);
    END LOOP;
    IF v_cur IS DISTINCT FROM t.pk THEN
      IF v_pk IS NOT NULL THEN EXECUTE format('ALTER TABLE ksx.%I DROP CONSTRAINT %I', t.tbl, v_pk); END IF;
      EXECUTE format('ALTER TABLE ksx.%I ADD CONSTRAINT %I PRIMARY KEY (%s)', t.tbl, 'pk_' || t.tbl,
                     (SELECT string_agg(format('%I', x), ', ') FROM unnest(t.pk) x));
    ELSIF v_pk <> 'pk_' || t.tbl THEN
      EXECUTE format('ALTER TABLE ksx.%I RENAME CONSTRAINT %I TO %I', t.tbl, v_pk, 'pk_' || t.tbl);
    END IF;
  END LOOP;
END $$;

-- ── 7) 명세에 없는 열 지우기 (옮겨 간 헤더 열, 없어진 식별자·섹션 목록). 레이크 기술 열·일련번호는 둔다 ──
DO $$
DECLARE c record;
BEGIN
  FOR c IN SELECT s.tbl, a.attname::text AS col FROM ksx_spec_table s
             JOIN pg_attribute a ON a.attrelid = ('ksx.' || s.tbl)::regclass AND a.attnum > 0 AND NOT a.attisdropped
            WHERE a.attname NOT LIKE 'lake\_%' AND a.attname NOT LIKE '%\_sequence\_no'
              AND NOT EXISTS (SELECT 1 FROM ksx_spec_col x WHERE x.tbl = s.tbl AND x.col = a.attname) LOOP
    EXECUTE format('ALTER TABLE ksx.%I DROP COLUMN %I', c.tbl, c.col);
  END LOOP;
END $$;

-- ── 8) 타입·NOT NULL 을 명세에 맞추기 ─────────────────────────────────────
DO $$
DECLARE c record; v_ty text; v_cur text; v_nn boolean;
BEGIN
  FOR c IN SELECT s.*, t.pk FROM ksx_spec_col s JOIN ksx_spec_table t USING (tbl) ORDER BY s.tbl, s.ord LOOP
    SELECT format_type(atttypid, atttypmod), attnotnull INTO v_cur, v_nn FROM pg_attribute
     WHERE attrelid = ('ksx.' || c.tbl)::regclass AND attname = c.col;
    EXECUTE format('SELECT format_type(%L::regtype, NULL)', split_part(c.typ, '(', 1)) INTO v_ty;
    IF c.typ LIKE '%(%' THEN v_ty := v_ty || substr(c.typ, strpos(c.typ, '(')); END IF;
    IF lower(replace(v_cur, ' ', '')) <> lower(replace(v_ty, ' ', '')) THEN
      EXECUTE format('ALTER TABLE ksx.%I ALTER COLUMN %I TYPE %s USING %I::%s', c.tbl, c.col, c.typ, c.col, c.typ);
    END IF;
    IF c.req AND NOT v_nn THEN
      EXECUTE format('ALTER TABLE ksx.%I ALTER COLUMN %I SET NOT NULL', c.tbl, c.col);
    ELSIF NOT c.req AND v_nn AND NOT c.col = ANY (c.pk) THEN
      EXECUTE format('ALTER TABLE ksx.%I ALTER COLUMN %I DROP NOT NULL', c.tbl, c.col);
    END IF;
  END LOOP;
END $$;

-- ── 9) 행 일련번호 (표준 ○○SequenceNo): 자동 증가 + 고유. 월 파티션 표는 시퀀스 기본값 ──
DO $$
DECLARE t record; v_col text;
BEGIN
  FOR t IN SELECT * FROM ksx_spec_table LOOP
    v_col := t.tbl || '_sequence_no';
    CONTINUE WHEN EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = ('ksx.' || t.tbl)::regclass AND attname = v_col AND NOT attisdropped);
    IF t.partitioned THEN
      EXECUTE format('CREATE SEQUENCE IF NOT EXISTS ksx.%I', v_col || '_seq');
      EXECUTE format('ALTER TABLE ksx.%I ADD COLUMN %I BIGINT NOT NULL DEFAULT nextval(%L)', t.tbl, v_col, 'ksx.' || v_col || '_seq');
      EXECUTE format('ALTER SEQUENCE ksx.%I OWNED BY ksx.%I.%I', v_col || '_seq', t.tbl, v_col);
    ELSE
      EXECUTE format('ALTER TABLE ksx.%I ADD COLUMN %I BIGINT GENERATED BY DEFAULT AS IDENTITY', t.tbl, v_col);
      EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS %I ON ksx.%I (%I)', 'ux_' || t.tbl || '_sequence_no', t.tbl, v_col);
    END IF;
  END LOOP;
END $$;

-- ── 10) FK 다시 걸기 (관계목록 '물리' 457건, 모두 DEFERRABLE) ─────────────────
-- @@FK@@

-- ── 11) 국문 주석 ─────────────────────────────────────────────────────────
-- @@COMMENTS@@

-- ── 12) 권한·RLS·덮어쓰기 전 행 보관 트리거 (새 표·이름 바뀐 표) ─────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ksx TO lake_loader;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ksx TO lake_loader;
GRANT SELECT ON ALL TABLES IN SCHEMA ksx TO lake_app, lake_agent;
SELECT gov.apply_scope_policies();
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

-- ── 13) 온톨로지 레지스트리·카탈로그 (클래스 76·속성·관계·표준 데이터셋·필드) ──────
-- @@SEED@@

-- 예전 클래스 → 새 클래스. 예전 명사 클래스를 가리키던 것(데이터셋·매핑·품질 규칙·확장 속성·제안…)은
-- 적재 단위인 라인(창고는 헤더)으로 옮기고, 표준 외 보조 헤더(arcon:)는 표준 헤더로 옮긴 뒤 예전 클래스를 지운다.
CREATE TEMP TABLE onto_class_map (old text PRIMARY KEY, new text NOT NULL) ON COMMIT DROP;
INSERT INTO onto_class_map VALUES
  ('https://ontology.impix.co.kr/ksx9101/SalesOrder', 'https://ontology.impix.co.kr/ksx9101/SalesOrderLine'),
  ('https://ontology.impix.co.kr/ksx9101/PurchaseOrder', 'https://ontology.impix.co.kr/ksx9101/PurchaseOrderLine'),
  ('https://ontology.impix.co.kr/ksx9101/UOMGroup', 'https://ontology.impix.co.kr/ksx9101/UOMGroupLine'),
  ('https://ontology.impix.co.kr/ksx9101/BOM', 'https://ontology.impix.co.kr/ksx9101/BOMLine'),
  ('https://ontology.impix.co.kr/ksx9101/Routing', 'https://ontology.impix.co.kr/ksx9101/RoutingLine'),
  ('https://ontology.impix.co.kr/ksx9101/WarehouseLocation', 'https://ontology.impix.co.kr/ksx9101/WarehouseLocationHeader'),
  ('https://ontology.impix.co.kr/ksx9101/ProductReleaseRequest', 'https://ontology.impix.co.kr/ksx9101/ProductReleaseRequestLine'),
  ('https://ontology.impix.co.kr/arcon/BOMHeader', 'https://ontology.impix.co.kr/ksx9101/BOMHeader'),
  ('https://ontology.impix.co.kr/arcon/RoutingHeader', 'https://ontology.impix.co.kr/ksx9101/RoutingHeader'),
  ('https://ontology.impix.co.kr/arcon/ProductReleaseRequestHeader', 'https://ontology.impix.co.kr/ksx9101/ProductReleaseRequestHeader');
CREATE TEMP TABLE std_dataset_map ON COMMIT DROP AS
  SELECT 'std.' || old AS old, 'std.' || new AS new FROM ksx_rename;

DO $$
DECLARE fk record; dm record;
BEGIN
  -- 클래스를 가리키는 모든 FK 열을 새 클래스로
  FOR fk IN SELECT c.conrelid::regclass AS rel, a.attname AS col FROM pg_constraint c
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
             WHERE c.contype = 'f' AND c.confrelid = 'onto.class'::regclass AND cardinality(c.conkey) = 1 LOOP
    EXECUTE format('UPDATE %s t SET %I = m.new FROM onto_class_map m WHERE t.%I = m.old', fk.rel, fk.col, fk.col);
  END LOOP;
  -- 범위가 예전 클래스였던 확장 속성 (FK 가 아닌 range_iri)
  UPDATE onto.property p SET range_iri = m.new FROM onto_class_map m WHERE p.range_iri = m.old;
  -- 표준 데이터셋: 예전 std.<표> 를 가리키던 것(계보·품질 실행·규칙·정책·문서…)을 새 데이터셋으로
  FOR fk IN SELECT c.conrelid::regclass AS rel, a.attname AS col FROM pg_constraint c
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
             WHERE c.contype = 'f' AND c.confrelid = 'catalog.dataset'::regclass AND cardinality(c.conkey) = 1
               AND c.conrelid <> 'catalog.dataset_field'::regclass LOOP
    EXECUTE format('UPDATE %s t SET %I = m.new FROM std_dataset_map m WHERE t.%I = m.old', fk.rel, fk.col, fk.col);
  END LOOP;
  FOR dm IN SELECT * FROM std_dataset_map LOOP
    DELETE FROM catalog.dataset_field WHERE dataset_id = dm.old;
    UPDATE catalog.dataset n SET last_ingested_at = greatest(n.last_ingested_at, o.last_ingested_at),
           quality_score = coalesce(n.quality_score, o.quality_score), quality_status = coalesce(nullif(n.quality_status, 'UNKNOWN'), o.quality_status)
      FROM catalog.dataset o WHERE o.dataset_id = dm.old AND n.dataset_id = dm.new;
    DELETE FROM catalog.dataset WHERE dataset_id = dm.old;
  END LOOP;
END $$;
DELETE FROM onto.class WHERE class_iri IN (SELECT old FROM onto_class_map);
-- 이번 릴리스에 없는 표준 속성(예전 생성본만 가진 것: 수주오더식별자·구매발주식별자·섹션 목록·보조 헤더 참조 등)은
-- 가리키는 곳을 비운 뒤 지운다. 사람이 만든 확장 속성(arcon 의 회사 확장)은 건드리지 않는다.
DO $$
DECLARE fk record; v_old text[];
BEGIN
  v_old := ARRAY(SELECT property_iri FROM onto.property
                  WHERE version_id = 'ksx9101-2025-v1.0-gen-0.2.0'
                    AND (property_iri LIKE 'https://ontology.impix.co.kr/ksx9101/%' OR property_iri LIKE 'https://ontology.impix.co.kr/arcon/hasHeader%'));
  FOR fk IN SELECT c.conrelid::regclass AS rel, a.attname AS col, a.attnotnull AS nn FROM pg_constraint c
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
             WHERE c.contype = 'f' AND c.confrelid = 'onto.property'::regclass AND cardinality(c.conkey) = 1 LOOP
    IF fk.nn THEN EXECUTE format('DELETE FROM %s WHERE %I = ANY ($1)', fk.rel, fk.col) USING v_old;
    ELSE EXECUTE format('UPDATE %s SET %I = NULL WHERE %I = ANY ($1)', fk.rel, fk.col, fk.col) USING v_old; END IF;
  END LOOP;
  UPDATE onto.property SET super_property_iri = NULL WHERE super_property_iri = ANY (v_old);
  DELETE FROM onto.property WHERE property_iri = ANY (v_old);
END $$;

-- ── 14) 주문 번호: 화면·리스크가 쓰던 수주오더식별자(SO-…)를 수주문서번호로 ─────────
UPDATE sem.risk_event r SET detail = jsonb_set(r.detail, '{sales_order_id}', to_jsonb(m.docno)),
       affected_iris = ARRAY(SELECT replace(x, '/salesOrder/' || m.sales_order_id, '/salesOrder/' || m.docno) FROM unnest(r.affected_iris) x)
  FROM so_id_map m
 WHERE r.enterprise_id = m.enterprise_id AND r.detail ->> 'sales_order_id' = m.sales_order_id AND m.docno <> m.sales_order_id;
UPDATE gov.action_execution e SET rationale = replace(e.rationale::text, ' ' || m.sales_order_id || ' ', ' ' || m.docno || ' ')::jsonb
  FROM so_id_map m
 WHERE e.enterprise_id = m.enterprise_id AND e.rationale::text LIKE '%' || m.sales_order_id || '%' AND m.docno <> m.sales_order_id;

-- ── 15) 활용 존 뷰: 주문 = 수주문서(헤더), 행 = 수주오더라인 ───────────────────
-- 화면·API 는 그대로 sales_order_id 라는 이름으로 수주문서번호를 받는다.
CREATE OR REPLACE VIEW mart.v_kpi_otd WITH (security_invoker = true) AS
WITH rel AS (
    SELECT pr.enterprise_id, pr.sales_document_number, pr.sales_document_sequence, pr.inventory_transaction_date,
           sum(pr.sales_quantity) OVER (PARTITION BY pr.enterprise_id, pr.sales_document_number, pr.sales_document_sequence
                                        ORDER BY pr.inventory_transaction_date, pr.product_release_id, pr.product_release_sequence) AS cum_qty
    FROM ksx.product_release pr
    WHERE coalesce(pr.return_indicator, FALSE) = FALSE
), agg AS (
    SELECT so.enterprise_id, so.plant_id, so.sales_document_number, so.sales_document_sequence,
           sh.customer_id, so.item_id, so.requested_delivery_date, so.item_quantity AS ordered_qty,
           min(rel.inventory_transaction_date) AS first_release_date,
           max(rel.cum_qty) AS released_qty,
           min(rel.inventory_transaction_date) FILTER (WHERE rel.cum_qty >= so.item_quantity) AS fulfilled_date
    FROM ksx.sales_order_line so
    LEFT JOIN ksx.sales_order_header sh ON sh.enterprise_id = so.enterprise_id AND sh.sales_document_number = so.sales_document_number
    LEFT JOIN rel ON rel.enterprise_id = so.enterprise_id AND rel.sales_document_number = so.sales_document_number
                 AND rel.sales_document_sequence = so.sales_document_sequence
    GROUP BY so.enterprise_id, so.plant_id, so.sales_document_number, so.sales_document_sequence,
             sh.customer_id, so.item_id, so.requested_delivery_date, so.item_quantity
)
SELECT enterprise_id, plant_id, sales_document_number AS sales_order_id, sales_document_number, sales_document_sequence, customer_id, item_id,
       requested_delivery_date, first_release_date, fulfilled_date, coalesce(released_qty, 0) AS released_qty, ordered_qty,
       CASE WHEN fulfilled_date IS NOT NULL THEN fulfilled_date <= requested_delivery_date
            WHEN requested_delivery_date < (now() AT TIME ZONE 'Asia/Seoul')::date THEN FALSE
            ELSE NULL END AS on_time
FROM agg;

CREATE OR REPLACE VIEW mart.v_otd_risk_candidate WITH (security_invoker = true) AS
WITH lot_defect AS (
    SELECT enterprise_id, lot_id, production_order_id, production_order_sequence, sum(defect_type_quantity) AS defect_qty
    FROM ksx.production_performance_quality GROUP BY 1,2,3,4
)
SELECT d.enterprise_id, d.lot_id, po.production_order_id, po.production_order_quantity, l.lot_created_quantity, d.defect_qty,
       round(100.0 * d.defect_qty / nullif(l.lot_created_quantity, 0), 2) AS defect_rate_pct,
       so.sales_document_number AS sales_order_id, sh.customer_id, so.requested_delivery_date,
       CASE WHEN so.requested_delivery_date <= (now() AT TIME ZONE 'Asia/Seoul')::date + 3 THEN 'CRITICAL' ELSE 'HIGH' END AS risk_level
FROM lot_defect d
JOIN ksx.lot l ON l.enterprise_id = d.enterprise_id AND l.lot_id = d.lot_id
JOIN ksx.production_order po ON po.enterprise_id = d.enterprise_id AND po.production_order_id = d.production_order_id
 AND po.production_order_sequence = d.production_order_sequence
JOIN ksx.sales_order_line so ON so.enterprise_id = po.enterprise_id AND so.sales_document_number = po.sales_document_number
 AND so.sales_document_sequence = po.sales_document_sequence
LEFT JOIN ksx.sales_order_header sh ON sh.enterprise_id = so.enterprise_id AND sh.sales_document_number = so.sales_document_number
WHERE d.defect_qty::numeric / nullif(l.lot_created_quantity, 0) > 0.03
  AND so.requested_delivery_date BETWEEN (now() AT TIME ZONE 'Asia/Seoul')::date AND (now() AT TIME ZONE 'Asia/Seoul')::date + 7;
GRANT SELECT ON mart.v_kpi_otd, mart.v_otd_risk_candidate TO lake_app, lake_agent;

-- ── 16) 기본 검사식: 구매발주 → 구매발주라인 ─────────────────────────────────
UPDATE catalog.quality_rule SET sql_check =
  'SELECT purchase_document_number || ''-'' || purchase_document_sequence AS focus_node, ''purchase_order_quantity'' AS result_path, ''발주 수량이 0 이하: '' || coalesce(purchase_order_quantity::text, ''없음'') AS message FROM ksx.purchase_order_line WHERE purchase_order_quantity IS NULL OR purchase_order_quantity <= 0'
 WHERE rule_id = 'po-quantity-positive' AND sql_check LIKE '%FROM ksx.purchase_order %';
UPDATE catalog.quality_rule SET sql_check =
  'SELECT p.purchase_document_number || ''-'' || p.purchase_document_sequence AS focus_node, ''item_id'' AS result_path, ''품목 '' || p.item_id || '' 이 품목 마스터에 없음'' AS message FROM ksx.purchase_order_line p LEFT JOIN ksx.item_master i ON i.enterprise_id = p.enterprise_id AND i.item_id = p.item_id WHERE p.item_id IS NOT NULL AND i.item_id IS NULL'
 WHERE rule_id = 'po-item-known' AND sql_check LIKE '%FROM ksx.purchase_order p %';
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT rule_id FROM catalog.quality_rule
            WHERE sql_check ~ 'ksx\.(sales_order|purchase_order|uom_group|bom|routing|warehouse_location|product_release_request)\M'
               OR sql_check ~ '\m(sales_order_id|purchase_order_id|warehouse_section_list)\M' LOOP
    RAISE WARNING '품질 규칙 % 의 검사식이 v1.0 최종본에서 바뀐 표·열을 씁니다. 품질 화면에서 고쳐 주세요', r.rule_id;
  END LOOP;
END $$;

-- ── 17) 적재 함수: 라인 표로 넣을 때 헤더 열로 헤더 행도 채우기, 자연 키로 식별자 만들기, 되돌리기 ──
-- 라인 표의 헤더: ksx.<x>_line → ksx.<x>_header 를 가리키는 헤더-라인 FK 가 있을 때
CREATE OR REPLACE FUNCTION gov.header_of(p_table text)
RETURNS TABLE (header regclass, line_cols text[], header_cols text[]) LANGUAGE sql STABLE SET search_path = pg_catalog AS $$
  SELECT c.confrelid::regclass,
         ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(n, i)
                 JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.n ORDER BY k.i),
         ARRAY(SELECT a.attname::text FROM unnest(c.confkey) WITH ORDINALITY k(n, i)
                 JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.n ORDER BY k.i)
    FROM pg_constraint c
   WHERE p_table ~ '_line$' AND c.contype = 'f' AND c.conrelid = to_regclass('ksx.' || p_table)
     AND c.confrelid = to_regclass('ksx.' || regexp_replace(p_table, '_line$', '_header'))
   LIMIT 1
$$;
GRANT EXECUTE ON FUNCTION gov.header_of(text) TO lake_app;

-- 식별자 자동 생성: 기본키·고유키 규칙(V0010)에 자연 키(gov.ksx_natural_key) 규칙을 더한다
CREATE OR REPLACE FUNCTION gov.auto_key_columns(p_table text, p_mapped text[])
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path = pg_catalog, gov AS $$
DECLARE
  v_rel regclass := ('ksx.' || p_table)::regclass;
  v_scope text[] := ARRAY['enterprise_id', 'site_id', 'plant_id'];
  v_pk text[]; v_seq jsonb := '{}'; v_der jsonb := '{}';
  key record; c text; v_sib text[]; v_ok boolean;
BEGIN
  SELECT array_agg(a.attname::text ORDER BY array_position(i.indkey::int2[], a.attnum)) INTO v_pk
    FROM pg_index i JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
   WHERE i.indrelid = v_rel AND i.indisprimary;
  FOR key IN
    SELECT k.contype, ARRAY(SELECT a.attname::text FROM unnest(k.conkey) WITH ORDINALITY o(n, i)
                             JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = o.n ORDER BY o.i) AS cols
      FROM pg_constraint k WHERE k.conrelid = v_rel AND k.contype IN ('p', 'u') ORDER BY k.contype DESC
  LOOP
    FOREACH c IN ARRAY key.cols LOOP
      CONTINUE WHEN c = ANY (p_mapped) OR v_seq ? c OR c NOT LIKE '%\_sequence';
      CONTINUE WHEN NOT EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = v_rel AND a.attname = c
                                   AND a.atttypid IN ('integer'::regtype, 'smallint'::regtype, 'bigint'::regtype));
      v_sib := ARRAY(SELECT x FROM unnest(key.cols) x WHERE x <> c AND NOT x = ANY (v_scope));
      IF v_sib <@ p_mapped THEN v_seq := v_seq || jsonb_build_object(c, to_jsonb(v_sib)); END IF;
    END LOOP;
  END LOOP;
  FOREACH c IN ARRAY coalesce(v_pk, '{}') LOOP
    CONTINUE WHEN c = ANY (p_mapped) OR c = ANY (v_scope) OR v_seq ? c;
    FOR key IN
      SELECT ARRAY(SELECT a.attname::text FROM unnest(k.conkey) WITH ORDINALITY o(n, i)
                     JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = o.n ORDER BY o.i) AS cols
        FROM pg_constraint k WHERE k.conrelid = v_rel AND k.contype = 'u'
      UNION ALL
      SELECT n.parts FROM gov.ksx_natural_key n WHERE n.table_name = p_table AND n.id_column = c
    LOOP
      v_sib := ARRAY(SELECT x FROM unnest(key.cols) x WHERE NOT x = ANY (v_scope));
      v_ok := cardinality(v_sib) > 0 AND NOT c = ANY (v_sib)
              AND NOT EXISTS (SELECT 1 FROM unnest(v_sib) x WHERE NOT (x = ANY (p_mapped) OR v_seq ? x));
      IF v_ok THEN v_der := v_der || jsonb_build_object(c, to_jsonb(v_sib)); EXIT; END IF;
    END LOOP;
  END LOOP;
  RETURN jsonb_build_object('seq', v_seq, 'derived', v_der);
END $$;

-- gov.standardize_batch: V0010 판에 헤더 채우기를 더했다.
--   대응표의 표준 열이 라인 표에 없고 그 헤더 표에 있으면(거래처·발주일 같은 헤더 열) 헤더 열로 받는다.
--   행마다 라인을 넣기 전에 헤더 행을 넣거나(없으면) 대응된 헤더 열을 새 값으로 바꾼다(빈 값은 예전 값 유지).
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
  v_cols  text[];
  v_pk    text[];
  v_auto  text[];
  v_set   text[];
  v_upd   text;
  v_sql   text;
  v_map   jsonb := '{}';
  v_all   jsonb;
  v_hmap  jsonb := '{}';   -- 헤더 열 대응 (표준 헤더 열 → 원천 열)
  v_hdr   regclass;
  v_hl    text[];          -- 라인 쪽 헤더 키 열
  v_hk    text[];          -- 헤더 쪽 키 열
  v_hcols text[];          -- 헤더 표의 열
  v_hset  text[];
  v_hsql  text;
  v_hobj  jsonb;
  v_hskip boolean;
  n_hdr   bigint := 0;
  n_one   int;
  v_run   uuid;
  v_mapid text;
  v_ver   int;
  rec     record;
  v_obj   jsonb;
  n_in bigint := 0; n_out bigint := 0; n_rej bigint := 0;
  v_errs  jsonb := '[]';
  k text; v text;
  fk      record;
  v_refs  jsonb := '[]';
  ref     jsonb;
  v_ro    jsonb;
  v_lv    text;
  v_skip  boolean;
  v_made  text[];
  n_made  int;
  v_refn  jsonb := '{}';
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
  SELECT h.header, h.line_cols, h.header_cols INTO v_hdr, v_hl, v_hk FROM gov.header_of(p_table) h;
  IF v_hdr IS NOT NULL THEN
    SELECT array_agg(attname::text ORDER BY attnum) INTO v_hcols
      FROM pg_attribute WHERE attrelid = v_hdr AND attnum > 0 AND NOT attisdropped;
  END IF;

  FOR k, v IN SELECT * FROM jsonb_each_text(coalesce(p_column_map, '{}')) LOOP
    CONTINUE WHEN v IS NULL OR v = '';
    IF v = 'enterprise_id' OR v LIKE 'lake\_%' OR v LIKE '%\_sequence\_no' THEN RAISE EXCEPTION '열 % 는 직접 채울 수 없습니다', v; END IF;
    IF v_map ? v OR v_hmap ? v THEN RAISE EXCEPTION '표준 열 % 에 원천 열이 둘 이상 대응됩니다', v; END IF;
    IF v = ANY (v_cols) THEN
      v_map := v_map || jsonb_build_object(v, k);
    ELSIF v_hdr IS NOT NULL AND v = ANY (v_hcols) THEN
      v_hmap := v_hmap || jsonb_build_object(v, k);
    ELSE
      RAISE EXCEPTION '표 % 에 열 % 가 없습니다', p_table, v;
    END IF;
  END LOOP;
  IF v_map = '{}' THEN RAISE EXCEPTION '대응시킨 열이 없습니다'; END IF;
  SELECT ARRAY(SELECT jsonb_object_keys(a -> 'seq')) || ARRAY(SELECT jsonb_object_keys(a -> 'derived')) INTO v_auto
    FROM gov.auto_key_columns(p_table, ARRAY(SELECT jsonb_object_keys(v_map))) a;
  IF EXISTS (SELECT 1 FROM unnest(v_pk) c WHERE c NOT IN ('enterprise_id', 'site_id', 'plant_id') AND NOT v_map ? c AND NOT c = ANY (v_auto)) THEN
    RAISE EXCEPTION '기본키 열(%)을 모두 대응시켜야 합니다', array_to_string(v_pk, ', ');
  END IF;

  v_set := ARRAY(SELECT jsonb_object_keys(v_map)) || ARRAY['enterprise_id'] || v_auto;
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

  -- 헤더 행: 키 + 회사·사업장·공장 + 대응된 헤더 열 + 적재 메타. 대응된 헤더 열이 없으면 없을 때만 넣는다.
  IF v_hdr IS NOT NULL THEN
    v_hset := v_hk || ARRAY(SELECT jsonb_object_keys(v_hmap))
              || ARRAY(SELECT c FROM unnest(ARRAY['enterprise_id', 'site_id', 'plant_id', 'lake_batch_id', 'lake_source_system',
                                                   'lake_loaded_at', 'lake_record_hash', 'lake_shacl_status']) c
                        WHERE c = ANY (v_hcols) AND NOT c = ANY (v_hk));
    v_hsql := format('INSERT INTO %1$s AS h (%2$s) SELECT %2$s FROM jsonb_populate_record(NULL::%1$s, $1) ON CONFLICT (%3$s) DO %4$s',
                     v_hdr, (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_hset) c),
                     (SELECT string_agg(format('%I', c), ', ') FROM unnest(v_hk) c),
                     CASE WHEN v_hmap = '{}' THEN 'NOTHING'
                          ELSE 'UPDATE SET ' || (SELECT string_agg(format('%1$I = coalesce(EXCLUDED.%1$I, h.%1$I)', c), ', ')
                                                   FROM jsonb_object_keys(v_hmap) c)
                               || ', lake_batch_id = EXCLUDED.lake_batch_id, lake_source_system = EXCLUDED.lake_source_system, '
                               || 'lake_loaded_at = EXCLUDED.lake_loaded_at, lake_record_hash = EXCLUDED.lake_record_hash, '
                               || 'lake_shacl_status = EXCLUDED.lake_shacl_status'
                               || ' WHERE (' || (SELECT string_agg(format('h.%1$I', c), ', ') FROM jsonb_object_keys(v_hmap) c)
                               || ') IS DISTINCT FROM ('
                               || (SELECT string_agg(format('coalesce(EXCLUDED.%1$I, h.%1$I)', c), ', ') FROM jsonb_object_keys(v_hmap) c)
                               || ')' END);
  END IF;

  IF p_create_refs THEN
    FOR fk IN
      SELECT c.confrelid,
             ARRAY(SELECT a.attname::text FROM unnest(c.conkey) WITH ORDINALITY k(n, i)
                     JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.n ORDER BY k.i) AS lcols,
             ARRAY(SELECT a.attname::text FROM unnest(c.confkey) WITH ORDINALITY k(n, i)
                     JOIN pg_attribute a ON a.attrelid = c.confrelid AND a.attnum = k.n ORDER BY k.i) AS rcols
        FROM pg_constraint c
       WHERE c.contype = 'f'   -- 라인 표의 참조 + 함께 채우는 헤더 표의 참조(공급업체 등)
         AND ((c.conrelid = v_rel AND c.confrelid IS DISTINCT FROM v_hdr) OR (v_hdr IS NOT NULL AND c.conrelid = v_hdr))
         AND c.confrelid NOT IN ('ksx.enterprise'::regclass, 'ksx.site'::regclass, 'ksx.plant'::regclass)
       ORDER BY c.conrelid = v_rel DESC, c.conname
    LOOP
      CONTINUE WHEN EXISTS (SELECT 1 FROM unnest(fk.lcols) l WHERE l NOT IN ('enterprise_id', 'site_id', 'plant_id')
                              AND NOT (v_map ? l OR v_hmap ? l));
      CONTINUE WHEN EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid = fk.confrelid AND a.attnum > 0 AND NOT a.attisdropped
                              AND a.attnotnull AND NOT a.atthasdef AND a.attidentity = ''
                              AND NOT a.attname::text = ANY (fk.rcols || ARRAY['enterprise_id', 'site_id', 'plant_id']));
      DECLARE
        v_names text[] := ARRAY(SELECT a.attname::text FROM pg_attribute a WHERE a.attrelid = fk.confrelid AND a.attnum > 0
                                  AND NOT a.attisdropped AND a.attname LIKE '%\_name' AND (v_map ? a.attname::text OR v_hmap ? a.attname::text)
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

  SET CONSTRAINTS ALL IMMEDIATE;
  FOR rec IN SELECT r.record_seq, r.payload, coalesce(f.fill, '{}') AS fill FROM raw.landing_record r
               LEFT JOIN gov.auto_key_fill(p_table, v_map, p_batch_id) f ON f.record_seq = r.record_seq
              WHERE r.batch_id = p_batch_id ORDER BY r.record_seq LOOP
    n_in := n_in + 1;
    SELECT jsonb_object_agg(t.key, nullif(btrim(rec.payload ->> (t.value #>> '{}')), ''))
      INTO v_obj FROM jsonb_each(v_map) t;
    v_obj := v_obj || jsonb_build_object('enterprise_id', v_ent,
               'lake_batch_id', p_batch_id, 'lake_source_system', b.source_system_id, 'lake_loaded_at', now(),
               'lake_record_hash', encode(sha256(convert_to(rec.payload::text, 'UTF8')), 'hex'),
               'lake_shacl_status', 'PENDING');
    v_obj := v_obj || rec.fill;
    IF 'site_id' = ANY (v_cols) AND (v_obj ->> 'site_id') IS NULL THEN v_obj := v_obj || jsonb_build_object('site_id', p_site_id); END IF;
    IF 'plant_id' = ANY (v_cols) AND (v_obj ->> 'plant_id') IS NULL THEN v_obj := v_obj || jsonb_build_object('plant_id', p_plant_id); END IF;
    BEGIN
      IF NOT gov.scope_ok(v_ent, v_obj ->> 'site_id', v_obj ->> 'plant_id') THEN
        RAISE EXCEPTION '사업장 %·공장 % 는 내 범위 밖입니다', v_obj ->> 'site_id', v_obj ->> 'plant_id';
      END IF;
      -- 헤더 열 값까지 합친 행 값: 참조 마스터 자동 등록이 헤더의 참조(공급업체 등)도 채우게
      SELECT v_obj || coalesce(jsonb_object_agg(t.key, nullif(btrim(rec.payload ->> (t.value #>> '{}')), '')), '{}')
        INTO v_all FROM jsonb_each(v_hmap) t;
      v_made := '{}';
      FOR ref IN SELECT * FROM jsonb_array_elements(v_refs) LOOP
        v_ro := jsonb_build_object('enterprise_id', v_ent, 'site_id', v_obj ->> 'site_id', 'plant_id', v_obj ->> 'plant_id',
                  'lake_batch_id', p_batch_id, 'lake_source_system', b.source_system_id, 'lake_loaded_at', now(),
                  'lake_shacl_status', 'PENDING');
        v_skip := false;
        FOR i IN 0 .. jsonb_array_length(ref -> 'l') - 1 LOOP
          v_lv := CASE WHEN ref -> 'l' ->> i = 'enterprise_id' THEN v_ent ELSE v_all ->> (ref -> 'l' ->> i) END;
          IF v_lv IS NULL THEN v_skip := true; EXIT; END IF;
          v_ro := v_ro || jsonb_build_object(ref -> 'r' ->> i, v_lv);
        END LOOP;
        CONTINUE WHEN v_skip;
        SELECT v_ro || coalesce(jsonb_object_agg(n, v_all -> n), '{}') INTO v_ro FROM jsonb_array_elements_text(ref -> 'names') n;
        v_ro := v_ro || jsonb_build_object('lake_record_hash', encode(sha256(convert_to(v_ro::text, 'UTF8')), 'hex'));
        EXECUTE ref ->> 'sql' USING v_ro;
        GET DIAGNOSTICS n_made = ROW_COUNT;
        IF n_made > 0 THEN v_made := v_made || (ref ->> 'rel'); END IF;
      END LOOP;
      IF v_hdr IS NOT NULL THEN
        v_hobj := jsonb_build_object('enterprise_id', v_ent, 'site_id', v_obj ->> 'site_id', 'plant_id', v_obj ->> 'plant_id',
                    'lake_batch_id', p_batch_id, 'lake_source_system', b.source_system_id, 'lake_loaded_at', now(),
                    'lake_shacl_status', 'PENDING');
        v_hskip := false;
        FOR i IN 1 .. cardinality(v_hk) LOOP
          IF v_obj ->> v_hl[i] IS NULL THEN v_hskip := true; EXIT; END IF;
          v_hobj := v_hobj || jsonb_build_object(v_hk[i], v_obj ->> v_hl[i]);
        END LOOP;
        IF NOT v_hskip THEN
          SELECT v_hobj || coalesce(jsonb_object_agg(t.key, nullif(btrim(rec.payload ->> (t.value #>> '{}')), '')), '{}')
            INTO v_hobj FROM jsonb_each(v_hmap) t;
          v_hobj := v_hobj || jsonb_build_object('lake_record_hash', encode(sha256(convert_to(v_hobj::text, 'UTF8')), 'hex'));
          EXECUTE v_hsql USING v_hobj;
          GET DIAGNOSTICS n_one = ROW_COUNT;
          n_hdr := n_hdr + n_one;
        END IF;
      END IF;
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

  UPDATE catalog.dataset_field f SET mapping_method = 'human', mapping_status = 'APPROVED', mapping_confidence = 1,
         label_ko = coalesce(f.label_ko, col_description(v_rel, (SELECT attnum FROM pg_attribute WHERE attrelid = v_rel AND attname = m.key)),
                             col_description(v_hdr, (SELECT attnum FROM pg_attribute WHERE attrelid = v_hdr AND attname = m.key)))
    FROM jsonb_each_text(v_map || v_hmap) m WHERE f.dataset_id = b.dataset_id AND f.field_name = m.value;
  IF v_std IS NOT NULL AND n_out > 0 THEN
    INSERT INTO catalog.lineage_edge (from_dataset_id, to_dataset_id, pipeline_id, field_map, enterprise_id)
    VALUES (b.dataset_id, v_std, 'p-console-std',
            (SELECT jsonb_object_agg(key, jsonb_build_array(value)) FROM jsonb_each(v_map)), v_ent)
    ON CONFLICT (from_dataset_id, to_dataset_id, pipeline_id) DO UPDATE SET field_map = EXCLUDED.field_map;
    UPDATE catalog.dataset SET last_ingested_at = now(), updated_at = now() WHERE dataset_id = v_std;
    IF v_hdr IS NOT NULL AND n_hdr > 0 THEN
      INSERT INTO catalog.lineage_edge (from_dataset_id, to_dataset_id, pipeline_id, field_map, enterprise_id)
      SELECT b.dataset_id, d.dataset_id, 'p-console-std',
             (SELECT jsonb_object_agg(key, jsonb_build_array(value)) FROM jsonb_each(v_hmap)), v_ent
        FROM catalog.dataset d WHERE d.location_uri = 'postgresql://lake/' || v_hdr::text
      ON CONFLICT (from_dataset_id, to_dataset_id, pipeline_id) DO UPDATE SET field_map = EXCLUDED.field_map;
      UPDATE catalog.dataset SET last_ingested_at = now(), updated_at = now() WHERE location_uri = 'postgresql://lake/' || v_hdr::text;
    END IF;
  END IF;
  IF v_class IS NOT NULL THEN
    UPDATE catalog.dataset SET represents_class_iri = coalesce(represents_class_iri, v_class) WHERE dataset_id = b.dataset_id;
  END IF;

  INSERT INTO gov.audit_log (channel, action, dataset_id, object_ref, query_text, row_count, result)
  VALUES ('UI', 'standardize', b.dataset_id, 'raw.ingest_batch:' || p_batch_id,
          'ksx.' || p_table || CASE WHEN n_hdr > 0 THEN ' +header ' || v_hdr::text || ' ' || n_hdr ELSE '' END
          || CASE WHEN v_refn <> '{}' THEN ' +refs ' || v_refn::text ELSE '' END, n_out,
          CASE WHEN n_out = 0 THEN 'ERROR' ELSE 'OK' END);
  RETURN jsonb_build_object('run_id', v_run, 'mapping_id', v_mapid, 'target', 'ksx.' || p_table, 'std_dataset_id', v_std,
                            'rows_in', n_in, 'rows_out', n_out, 'rows_rejected', n_rej, 'errors', v_errs,
                            'refs_created', v_refn, 'header', v_hdr::text, 'header_rows', n_hdr);
END $$;
REVOKE ALL ON FUNCTION gov.standardize_batch(uuid, text, jsonb, text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION gov.standardize_batch(uuid, text, jsonb, text, text, boolean) TO lake_app;

-- 되돌리기: V0013 판 + 라인 표면 이 배치가 넣은 헤더 중 라인이 남지 않은 것도 뺀다(덮어썼던 헤더는 보관본으로 되살아난다)
CREATE OR REPLACE FUNCTION gov.rollback_batch(p_batch_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, gov AS $$
DECLARE v_ent text := gov.require_ingest_role(); b raw.ingest_batch; n bigint := 0; n_ext bigint := 0; n_back bigint := 0; n_one bigint;
        n_hdr bigint := 0; v_std text; t record; v_cols text; h record;
BEGIN
  SELECT * INTO b FROM raw.ingest_batch WHERE batch_id = p_batch_id FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM catalog.dataset d WHERE d.dataset_id = b.dataset_id AND d.enterprise_id = v_ent) THEN
    RAISE EXCEPTION '배치 % 가 없거나 다른 회사 것입니다', p_batch_id;
  END IF;
  IF b.std_table IS NULL OR b.status NOT IN ('STANDARDIZED', 'REJECTED') THEN RAISE EXCEPTION '표준 존에 넣지 않은 배치는 되돌릴 것이 없습니다'; END IF;
  IF to_regclass(b.std_table) IS NULL OR b.std_table !~ '^ksx\.[a-z][a-z0-9_]{0,62}$' THEN RAISE EXCEPTION '표준 표 % 가 없습니다', b.std_table; END IF;
  EXECUTE format('DELETE FROM %s WHERE lake_batch_id = $1 AND enterprise_id = $2', b.std_table) USING p_batch_id, v_ent;
  GET DIAGNOSTICS n = ROW_COUNT;
  SELECT * INTO h FROM gov.header_of(substr(b.std_table, 5));
  IF h.header IS NOT NULL THEN
    EXECUTE format('DELETE FROM %s x WHERE x.lake_batch_id = $1 AND x.enterprise_id = $2 AND NOT EXISTS (SELECT 1 FROM %s l WHERE %s)',
                   h.header, b.std_table,
                   (SELECT string_agg(format('l.%I = x.%I', h.line_cols[i], h.header_cols[i]), ' AND ')
                      FROM generate_subscripts(h.line_cols, 1) i)) USING p_batch_id, v_ent;
    GET DIAGNOSTICS n_hdr = ROW_COUNT;
  END IF;
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
                            'header_rows', n_hdr, 'extension_rows', n_ext, 'restored_rows', n_back);
END $$;
