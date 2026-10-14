-- =============================================================================
-- 온톨로지 기반 데이터레이크 — 스키마 골격 (PostgreSQL 16)
-- 대상: 온프레미스 PostgreSQL 16 (+ pgvector, TimescaleDB 확장)
-- 적용 순서: 00 → 10 → 11 → 20 → 21 → 30 → (31: TimescaleDB 있을 때) → 40 → 50 → 60 → 70 → 90 → 91
--
--  raw      원천 존      원천 포맷 그대로, append-only (JSONB · 파일 포인터 · 시계열 원본)
--  ksx      표준 존      KS X 9101-1:2025 70 테이블 — Ontop 가상화의 원장
--  sem      시맨틱 존    RDF 쿼드 · 추론 결과 · 동일성 판정 · 임베딩
--  mart     활용 존      KPI 뷰 · 계보 뷰 · 규격이탈/납기리스크 후보
--  onto     온톨로지 레지스트리 (클래스·속성·관계·액션·버전)
--  catalog  데이터 카탈로그 (데이터셋·필드 매핑·계보·품질·원천 문서)
--  gov      거버넌스 (역할·범위·신청승인·토큰·감사로그·액션 정책/실행)
--
-- 오브젝트 스토리지(MinIO/Ceph)·트리플스토어(Fuseki)에 있는 실체는 catalog.dataset.location_uri 로 가리킨다.
-- 설비 시계열(TimescaleDB 하이퍼테이블)과 임베딩 벡터(pgvector)는 같은 PG 안에 둔다.
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS ksx;
CREATE SCHEMA IF NOT EXISTS sem;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS onto;
CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS gov;

COMMENT ON SCHEMA raw     IS '원천 존 — 원천 포맷 보존, 불변';
COMMENT ON SCHEMA ksx     IS '표준 존 — KS X 9101-1:2025 v1.0 테이블';
COMMENT ON SCHEMA sem     IS '시맨틱 존 — 지식그래프 쿼드·추론·임베딩';
COMMENT ON SCHEMA mart    IS '활용 존 — KPI·피처·서빙 뷰';
COMMENT ON SCHEMA onto    IS '온톨로지 레지스트리';
COMMENT ON SCHEMA catalog IS '데이터 카탈로그·계보·품질';
COMMENT ON SCHEMA gov     IS '접근·감사·액션 거버넌스';

-- 타임존 규약 (리뷰 F10) -------------------------------------------------------
-- 표준 존(ksx)의 *_date_time·*_time 은 표준 DDL 대로 TIMESTAMP(타임존 없음)이고 "한국 표준시 벽시계"로 저장한다.
-- 레이크 자체 컬럼(raw.ts_point.ts, lake_loaded_at, gov·sem 시각)은 TIMESTAMPTZ.
-- 두 형이 섞여 비교되므로 DB 와 레이크 역할의 세션 타임존을 Asia/Seoul 로 고정한다(역할 설정은 70_rls.sql).
-- 원천 → 표준 존 승격은 항상 명시 변환: ksx.trace_parameter.event_date_time = raw.ts_point.ts AT TIME ZONE 'Asia/Seoul'
DO $$ BEGIN EXECUTE format('ALTER DATABASE %I SET timezone = %L', current_database(), 'Asia/Seoul'); END $$;
SET timezone = 'Asia/Seoul';

-- 스키마 버전 기록 (리뷰 F21) -------------------------------------------------
-- db/apply.sh 가 파일마다 한 트랜잭션으로 적용하고 여기에 남긴다. 이미 적용된 파일은 건너뛴다.
-- 운영 반영은 증분 마이그레이션(V0002__*.sql …)으로 하고, 지금 파일들은 V0001 기준선이다.
CREATE TABLE IF NOT EXISTS gov.schema_migration (
    version      VARCHAR(100) PRIMARY KEY,     -- 파일명 (예: 40_sem.sql, V0002__add_x.sql)
    checksum     CHAR(64) NOT NULL,            -- 파일 sha256 — 적용 후 파일이 바뀌면 apply 가 경고
    applied_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    applied_by   VARCHAR(100) NOT NULL DEFAULT current_user
);

-- 확장 ---------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS vector;          -- pgvector: sem.embedding_item
-- TimescaleDB 는 postgresql.conf 의 shared_preload_libraries = 'timescaledb' 가 먼저 필요하다.
-- 설치돼 있지 않으면 경고만 내고 넘어가며, raw.ts_point 는 일 파티션으로 대체 생성된다(30_raw.sql).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'timescaledb') THEN
    CREATE EXTENSION IF NOT EXISTS timescaledb;
  ELSE
    RAISE WARNING 'timescaledb 확장이 없습니다. raw.ts_point 는 일 파티션 대체 경로가 됩니다(운영 금지).';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'timescaledb 를 활성화하지 못했습니다(%). shared_preload_libraries 를 확인하세요.', SQLERRM;
END $$;

-- 파티션 유지 (리뷰 F8) -------------------------------------------------------
-- 월/일 파티션을 앞당겨 만든다. 매일 cron(또는 pg_cron)으로 돌린다:
--   SELECT gov.ensure_partitions('raw.landing_record', 'month', 3);
--   SELECT gov.ensure_partitions('gov.audit_log', 'month', 3);
-- DEFAULT 파티션에 행이 쌓이면 새 파티션을 만들 수 없으므로 gov.default_partition_rows() 가 0 이 아니면 알람.
-- 경계는 항상 한국 표준시 자정 (재검토 N6): cron 세션이 UTC 여도 같은 경계가 나오도록 함수 안에서 타임존을 고정한다.
CREATE OR REPLACE FUNCTION gov.ensure_partitions(p_parent regclass, p_unit text, p_ahead int)
RETURNS int LANGUAGE plpgsql SET timezone = 'Asia/Seoul' AS $$
DECLARE
  step interval := CASE p_unit WHEN 'month' THEN interval '1 month' WHEN 'day' THEN interval '1 day' END;
  fmt  text     := CASE p_unit WHEN 'month' THEN 'YYYY_MM' ELSE 'YYYY_MM_DD' END;
  nsp text; rel text; d timestamptz; part text; made int := 0;
BEGIN
  IF step IS NULL THEN RAISE EXCEPTION 'p_unit 은 month 또는 day'; END IF;
  SELECT n.nspname, c.relname INTO nsp, rel FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.oid = p_parent;
  FOR i IN -1 .. p_ahead LOOP
    d := date_trunc(p_unit, now()) + step * i;
    part := rel || '_' || to_char(d, fmt);
    CONTINUE WHEN EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE n.nspname = nsp AND c.relname = part);
    BEGIN
      EXECUTE format('CREATE TABLE %I.%I PARTITION OF %s FOR VALUES FROM (%L) TO (%L)', nsp, part, p_parent, d, d + step);
      -- 감사로그 파티션은 직접 TRUNCATE 도 막는다 (재검토 N9: 부모의 TRUNCATE 트리거는 자식에 상속되지 않음)
      IF p_parent = to_regclass('gov.audit_log') AND to_regprocedure('gov.raise_immutable()') IS NOT NULL THEN
        EXECUTE format('CREATE TRIGGER trg_audit_no_truncate BEFORE TRUNCATE ON %I.%I FOR EACH STATEMENT EXECUTE FUNCTION gov.raise_immutable()', nsp, part);
      END IF;
      made := made + 1;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '% 생성 실패: % (DEFAULT 파티션에 해당 기간 행이 있는지 확인)', part, SQLERRM;
    END;
  END LOOP;
  -- 새 파티션도 부모와 같은 RLS 정책을 받아야 직접 조회로 새지 않는다 (70_rls.sql 이 적용된 뒤부터)
  -- 이미 정책이 있는 테이블은 건드리지 않으므로 새 파티션에만 잠금이 걸린다 (재검토 N3)
  IF made > 0 AND to_regprocedure('gov.apply_scope_policies(boolean)') IS NOT NULL THEN
    BEGIN
      PERFORM gov.apply_scope_policies();
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE WARNING '새 파티션에 RLS 를 걸지 못했습니다(테이블 소유자로 gov.apply_scope_policies() 실행 필요): %', SQLERRM;
    END;
  END IF;
  RETURN made;
END $$;

CREATE OR REPLACE FUNCTION gov.default_partition_rows()
RETURNS TABLE (partition_name text, row_count bigint) LANGUAGE plpgsql STABLE AS $$
DECLARE r record;
BEGIN
  FOR r IN SELECT c.oid::regclass AS rc FROM pg_class c JOIN pg_inherits i ON i.inhrelid = c.oid
           WHERE c.relname LIKE '%\_default' LOOP
    partition_name := r.rc::text;
    EXECUTE format('SELECT count(*) FROM %s', r.rc) INTO row_count;
    RETURN NEXT;
  END LOOP;
END $$;
