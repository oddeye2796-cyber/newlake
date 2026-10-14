-- =============================================================================
-- 원천 존 시계열 — TimescaleDB (온프레미스 PG 에 timescaledb 확장이 있을 때만 적용)
-- db/apply.sh 가 확장 유무를 보고 자동으로 실행하거나 건너뛴다.
-- 연속 집계는 트랜잭션 블록 안에서 만들 수 없어서 별도 파일로 뺐다.
--
--  · 청크 12시간 · 2일 지나면 압축 · 6개월 보존(catalog.zone RAW 와 같게)
--    용량 추정(리뷰 F29): 하루 8,600만 행 × 약 170B ≈ 15GB/일. 압축 전 구간을 짧게 둬서 비압축 보유량을 30GB 안팎으로.
--  · 압축 세그먼트는 (회사, 설비). 설비×파라미터로 쪼개면 세그먼트당 행이 수백 개로 줄어 압축률이 떨어진다.
--    파라미터는 orderby 앞에 둬서 설비 안에서 파라미터별로 연속 저장한다. 운영 데이터로 압축률을 비교해 조정할 것.
--  · 2일 이후 지연 도착분은 압축 청크에 들어가 느리다. 지연이 잦은 원천은 압축 지연을 늘린다.
--  · 1분 집계 연속 집계 raw.ts_point_1m (대시보드·규격이탈 승격 입력)
--  · 행 단위 보안은 걸지 않는다. 원천 존은 GRANT 로 적재·ML 역할만 읽는다(70_rls.sql).
-- =============================================================================
SELECT create_hypertable('raw.ts_point', 'ts', chunk_time_interval => INTERVAL '12 hours', if_not_exists => TRUE);

ALTER TABLE raw.ts_point SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'enterprise_id, equipment_id',
    timescaledb.compress_orderby   = 'parameter_id, ts DESC'
);
SELECT add_compression_policy('raw.ts_point', INTERVAL '2 days', if_not_exists => TRUE);
SELECT add_retention_policy('raw.ts_point', INTERVAL '6 months', if_not_exists => TRUE);

CREATE MATERIALIZED VIEW IF NOT EXISTS raw.ts_point_1m
WITH (timescaledb.continuous) AS
SELECT enterprise_id, equipment_id, parameter_id,
       time_bucket(INTERVAL '1 minute', ts) AS bucket,
       avg(value_num) AS avg_val, min(value_num) AS min_val, max(value_num) AS max_val, count(*) AS n
  FROM raw.ts_point
 GROUP BY enterprise_id, equipment_id, parameter_id, bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('raw.ts_point_1m',
    start_offset => INTERVAL '1 day', end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute', if_not_exists => TRUE);
SELECT add_retention_policy('raw.ts_point_1m', INTERVAL '2 years', if_not_exists => TRUE);

COMMENT ON TABLE raw.ts_point IS '설비 파라미터 원본 시계열 (TimescaleDB 하이퍼테이블, 12시간 청크, 2일 후 압축, 6개월 보존)';
