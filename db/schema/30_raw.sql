-- =============================================================================
-- 원천 존 (raw) — 원천 포맷 보존, append-only, 월 파티션
-- 대용량 파일·시계열 원본은 오브젝트 스토리지/시계열DB에 두고 여기엔 포인터·배치 메타만 둔다.
-- =============================================================================
CREATE TABLE raw.ingest_batch (
    batch_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_system_id  VARCHAR(50) NOT NULL REFERENCES catalog.source_system(source_system_id),
    dataset_id        VARCHAR(150) NOT NULL REFERENCES catalog.dataset(dataset_id),
    job_run_id        UUID REFERENCES catalog.job_run(run_id),
    bod_id            UUID,                       -- KS X 9101 BOD 로 수신한 경우 BODID
    scenario_id       VARCHAR(10),                -- 부속서 A 시나리오 번호
    received_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    record_count      BIGINT,
    byte_size         BIGINT,
    checksum          CHAR(64),
    status            VARCHAR(12) NOT NULL DEFAULT 'LANDED' CHECK (status IN ('LANDED','STANDARDIZED','REJECTED','QUARANTINED'))
);

-- 정형/반정형 원천 레코드 (API·CDC·BOD 본문)
CREATE TABLE raw.landing_record (
    batch_id          UUID NOT NULL REFERENCES raw.ingest_batch(batch_id),
    record_seq        BIGINT NOT NULL,
    received_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_entity     VARCHAR(100) NOT NULL,      -- 원천 테이블/토픽/BOD 명사
    source_key        VARCHAR(300),
    op                CHAR(1) CHECK (op IN ('I','U','D','S')),   -- CDC 연산 (S=스냅샷)
    payload           JSONB NOT NULL,
    PRIMARY KEY (received_at, batch_id, record_seq)
) PARTITION BY RANGE (received_at);
CREATE TABLE raw.landing_record_default PARTITION OF raw.landing_record DEFAULT;
SELECT gov.ensure_partitions('raw.landing_record', 'month', 3);   -- 지난달~3개월 뒤, 이후는 cron
CREATE INDEX ix_landing_entity ON raw.landing_record (source_entity, source_key);

-- 파일 (CSV·XLSX·PDF·이미지·장비 로그) — 실체는 오브젝트 스토리지
CREATE TABLE raw.landing_file (
    file_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id          UUID NOT NULL REFERENCES raw.ingest_batch(batch_id),
    object_uri        VARCHAR(1000) NOT NULL,     -- s3://lake-raw/{source}/{yyyy}/{mm}/{dd}/...
    file_name         VARCHAR(500) NOT NULL,
    mime_type         VARCHAR(100),
    byte_size         BIGINT,
    sha256            CHAR(64) NOT NULL,
    received_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 설비 시계열 원본 (SECS/GEM·OPC-UA·센서). 운영에서는 IoTDB/TimescaleDB 로 분리 가능.
-- 규격 이탈·상태 전이 구간만 표준 존 ksx.trace_parameter 및 시맨틱 존 트리플로 승격한다.
-- TimescaleDB 가 있으면 일반 테이블로 만든 뒤 31_raw_timescale.sql 에서 하이퍼테이블로 바꾼다.
-- 없으면 월 파티션 + 1분 집계 일반 뷰로 대체한다(이름은 같아서 하류 쿼리는 그대로).
DO $$
DECLARE ddl text := $ddl$
CREATE TABLE raw.ts_point (
    enterprise_id     VARCHAR(50) NOT NULL,
    equipment_id      VARCHAR(50) NOT NULL,
    parameter_id      VARCHAR(50) NOT NULL,
    ts                TIMESTAMPTZ NOT NULL,
    value_num         DOUBLE PRECISION,
    value_text        VARCHAR(200),
    batch_id          UUID,
    PRIMARY KEY (enterprise_id, equipment_id, parameter_id, ts)
)$ddl$;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb') THEN
    EXECUTE ddl;
  ELSE
    EXECUTE ddl || ' PARTITION BY RANGE (ts)';
    EXECUTE $p$CREATE TABLE raw.ts_point_default PARTITION OF raw.ts_point DEFAULT$p$;
    PERFORM gov.ensure_partitions('raw.ts_point', 'day', 14);   -- 대체 경로는 일 파티션 (보존은 DROP 으로)
    EXECUTE $v$CREATE VIEW raw.ts_point_1m AS
      SELECT enterprise_id, equipment_id, parameter_id, date_trunc('minute', ts) AS bucket,
             avg(value_num) AS avg_val, min(value_num) AS min_val, max(value_num) AS max_val, count(*) AS n
        FROM raw.ts_point GROUP BY 1, 2, 3, 4$v$;
  END IF;
END $$;
