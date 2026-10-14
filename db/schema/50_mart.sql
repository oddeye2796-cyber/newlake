-- =============================================================================
-- 활용 존 (mart) — 표준 명사만으로 닫히는 KPI·추적 뷰
-- 운영에서는 일 배치로 물질화(materialized view 또는 Iceberg 테이블)하고 catalog.dataset 에 CURATED 로 등록한다.
-- 오늘 날짜는 세션 타임존과 무관하게 한국 날짜로: (now() AT TIME ZONE 'Asia/Seoul')::date (재검토 N7)
-- 수량 정의 가정: produced_quantity 는 불량 포함 총 생산수량 (표준 정의 확인 필요)
-- =============================================================================

-- 로트 계보 전수 (arcon:derivedFrom 전이 폐포의 SQL 판)
CREATE OR REPLACE VIEW mart.v_lot_genealogy WITH (security_invoker = true) AS
WITH RECURSIVE g AS (
    SELECT enterprise_id, lot_id, parent_lot_id AS ancestor_lot_id, 1 AS depth,
           ARRAY[lot_id::text, parent_lot_id::text] AS path
    FROM ksx.lot WHERE parent_lot_id IS NOT NULL
  UNION ALL
    SELECT g.enterprise_id, g.lot_id, l.parent_lot_id, g.depth + 1, g.path || l.parent_lot_id::text
    FROM g JOIN ksx.lot l ON l.enterprise_id = g.enterprise_id AND l.lot_id = g.ancestor_lot_id
    WHERE l.parent_lot_id IS NOT NULL AND NOT l.parent_lot_id = ANY (g.path) AND g.depth < 50
)
SELECT enterprise_id, lot_id, ancestor_lot_id, depth, path FROM g;
COMMENT ON VIEW mart.v_lot_genealogy IS '로트 → 모든 선조 로트 (순환 방지, 최대 50단)';

-- 양품율 (일·품목)
CREATE OR REPLACE VIEW mart.v_kpi_yield_daily WITH (security_invoker = true) AS
SELECT enterprise_id, site_id, plant_id, production_performance_date AS perf_date, item_id,
       sum(produced_quantity) AS produced_qty,
       sum(coalesce(defect_quantity, 0)) AS defect_qty,
       round(100 * (1 - sum(coalesce(defect_quantity,0)) / nullif(sum(produced_quantity), 0)), 2) AS yield_pct
FROM ksx.production_performance
WHERE coalesce(cancel_indicator, FALSE) = FALSE
GROUP BY enterprise_id, site_id, plant_id, production_performance_date, item_id;

-- 공정 불량 PPM (일·공정·불량유형)
CREATE OR REPLACE VIEW mart.v_kpi_process_ppm WITH (security_invoker = true) AS
-- 분모는 불량 유무와 상관없이 그날 그 공정의 전체 생산 수량 (리뷰 F6). 공정 기준은 생산실적의 operation_id.
WITH d AS (
    SELECT enterprise_id, plant_id, production_performance_date AS perf_date, operation_id, sum(produced_quantity) AS produced_qty
    FROM ksx.production_performance
    WHERE coalesce(cancel_indicator, FALSE) = FALSE
    GROUP BY 1,2,3,4
), n AS (
    SELECT p.enterprise_id, p.plant_id, p.production_performance_date AS perf_date, p.operation_id,
           q.defect_type_code, sum(q.defect_type_quantity) AS defect_qty
    FROM ksx.production_performance_quality q
    JOIN ksx.production_performance p
      ON p.enterprise_id = q.enterprise_id AND p.production_performance_id = q.production_performance_id
     AND p.production_performance_sequence = q.production_performance_sequence
    WHERE coalesce(p.cancel_indicator, FALSE) = FALSE
    GROUP BY 1,2,3,4,5
)
SELECT d.enterprise_id, d.plant_id, d.perf_date, d.operation_id, n.defect_type_code,
       coalesce(n.defect_qty, 0) AS defect_qty, d.produced_qty,
       round(1e6 * coalesce(n.defect_qty, 0) / nullif(d.produced_qty, 0)) AS ppm
FROM d LEFT JOIN n USING (enterprise_id, plant_id, perf_date, operation_id);

-- 설비 시간가동율 (일·설비) = 가동 / (가동 + 준비)
CREATE OR REPLACE VIEW mart.v_kpi_equipment_time_util WITH (security_invoker = true) AS
SELECT enterprise_id, plant_id, equipment_id, execution_start_date_time::date AS perf_date,
       sum(run_time) AS run_time, sum(setup_time) AS setup_time,
       round(100 * extract(epoch FROM sum(run_time)) /
             nullif(extract(epoch FROM sum(run_time) + coalesce(sum(setup_time), interval '0')), 0), 2) AS time_util_pct,
       sum(produced_quantity) AS produced_qty, sum(defect_quantity) AS defect_qty
FROM ksx.production_performance_equipment
WHERE coalesce(cancel_indicator, FALSE) = FALSE
GROUP BY 1,2,3,4;

-- 납기준수율 (수주 행 단위) — 리뷰 F23
-- 완납일 = 누적 출고 수량이 주문 수량에 처음 도달한 출고일. 부분 출고만으로는 납기 준수가 아니다.
--   완납일 ≤ 납기 → TRUE, 완납일 > 납기 → FALSE, 미완납인데 납기가 지남 → FALSE, 미완납·납기 전 → NULL(판정 보류)
CREATE OR REPLACE VIEW mart.v_kpi_otd WITH (security_invoker = true) AS
WITH rel AS (
    SELECT pr.enterprise_id, pr.sales_document_number, pr.sales_document_sequence, pr.inventory_transaction_date,
           sum(pr.sales_quantity) OVER (PARTITION BY pr.enterprise_id, pr.sales_document_number, pr.sales_document_sequence
                                        ORDER BY pr.inventory_transaction_date, pr.product_release_id, pr.product_release_sequence) AS cum_qty
    FROM ksx.product_release pr
    WHERE coalesce(pr.return_indicator, FALSE) = FALSE
), agg AS (
    SELECT so.enterprise_id, so.plant_id, so.sales_order_id, so.sales_document_number, so.sales_document_sequence,
           so.customer_id, so.item_id, so.requested_delivery_date, so.item_quantity AS ordered_qty,
           min(rel.inventory_transaction_date) AS first_release_date,
           max(rel.cum_qty) AS released_qty,
           min(rel.inventory_transaction_date) FILTER (WHERE rel.cum_qty >= so.item_quantity) AS fulfilled_date
    FROM ksx.sales_order so
    LEFT JOIN rel ON rel.enterprise_id = so.enterprise_id AND rel.sales_document_number = so.sales_document_number
                 AND rel.sales_document_sequence = so.sales_document_sequence
    GROUP BY so.enterprise_id, so.plant_id, so.sales_order_id, so.sales_document_number, so.sales_document_sequence,
             so.customer_id, so.item_id, so.requested_delivery_date, so.item_quantity
)
SELECT enterprise_id, plant_id, sales_order_id, sales_document_number, sales_document_sequence, customer_id, item_id,
       requested_delivery_date, first_release_date, fulfilled_date, coalesce(released_qty, 0) AS released_qty, ordered_qty,
       CASE WHEN fulfilled_date IS NOT NULL THEN fulfilled_date <= requested_delivery_date
            WHEN requested_delivery_date < (now() AT TIME ZONE 'Asia/Seoul')::date THEN FALSE
            ELSE NULL END AS on_time
FROM agg;

-- 규격 이탈 → 그 시각 그 설비에서 진행 중이던 로트 (arcon:SpecOutEvent 후보, 시계열 → 트리플 승격 기준)
CREATE OR REPLACE VIEW mart.v_spec_out_lot WITH (security_invoker = true) AS
-- 이벤트 시각 이전의 가장 최근 착공 1건만 고르고, 그 착공이 이미 끝났으면 "진행 로트 없음"(lot_id NULL)으로 남긴다 (리뷰 F5).
-- 이탈 이벤트는 항상 1행 — 승격 파이프라인이 risk_event 를 중복 생성하지 않는다.
SELECT tp.enterprise_id, tp.plant_id, tp.equipment_id, tp.parameter_id, ep.parameter_name,
       tp.event_date_time, tp.parameter_value, ep.lsl, ep.usl,
       CASE WHEN oe.operation_end_time IS NULL OR tp.event_date_time <= oe.operation_end_time THEN os.lot_id END AS lot_id,
       CASE WHEN oe.operation_end_time IS NULL OR tp.event_date_time <= oe.operation_end_time THEN os.operation_id END AS operation_id,
       os.operation_start_time, oe.operation_end_time
FROM ksx.trace_parameter tp
JOIN ksx.equipment_parameter ep ON ep.enterprise_id = tp.enterprise_id AND ep.parameter_id = tp.parameter_id
LEFT JOIN LATERAL (
    SELECT s.lot_id, s.operation_id, s.operation_start_time FROM ksx.operation_start s
    WHERE s.enterprise_id = tp.enterprise_id AND s.equipment_id = tp.equipment_id
      AND s.operation_start_time <= tp.event_date_time
    ORDER BY s.operation_start_time DESC LIMIT 1
) os ON TRUE
LEFT JOIN LATERAL (
    SELECT min(e.operation_end_time) AS operation_end_time FROM ksx.operation_end e
    WHERE e.enterprise_id = tp.enterprise_id AND e.lot_id = os.lot_id AND e.operation_id = os.operation_id
      AND e.operation_end_time >= os.operation_start_time
) oe ON TRUE
WHERE tp.parameter_value < ep.lsl OR tp.parameter_value > ep.usl;
CREATE INDEX IF NOT EXISTS ix_operation_start_eq_time ON ksx.operation_start (enterprise_id, equipment_id, operation_start_time DESC);

-- 납기 리스크 후보 (rules/otd-risk 의 SQL 판): 불량률 > 3% 인 로트의 수주가 7일 이내 납기
-- 불량률 분모는 그 로트의 수량(lot_created_quantity). 생산지시 수량을 쓰면 지시 1건에 로트가 여럿일 때 1/N 로 희석된다 (리뷰 F23).
CREATE OR REPLACE VIEW mart.v_otd_risk_candidate WITH (security_invoker = true) AS
WITH lot_defect AS (
    SELECT enterprise_id, lot_id, production_order_id, production_order_sequence, sum(defect_type_quantity) AS defect_qty
    FROM ksx.production_performance_quality GROUP BY 1,2,3,4
)
SELECT d.enterprise_id, d.lot_id, po.production_order_id, po.production_order_quantity, l.lot_created_quantity, d.defect_qty,
       round(100.0 * d.defect_qty / nullif(l.lot_created_quantity, 0), 2) AS defect_rate_pct,
       so.sales_order_id, so.customer_id, so.requested_delivery_date,
       CASE WHEN so.requested_delivery_date <= (now() AT TIME ZONE 'Asia/Seoul')::date + 3 THEN 'CRITICAL' ELSE 'HIGH' END AS risk_level
FROM lot_defect d
JOIN ksx.lot l ON l.enterprise_id = d.enterprise_id AND l.lot_id = d.lot_id
JOIN ksx.production_order po ON po.enterprise_id = d.enterprise_id AND po.production_order_id = d.production_order_id
 AND po.production_order_sequence = d.production_order_sequence
JOIN ksx.sales_order so ON so.enterprise_id = po.enterprise_id AND so.sales_document_number = po.sales_document_number
 AND so.sales_document_sequence = po.sales_document_sequence
WHERE d.defect_qty::numeric / nullif(l.lot_created_quantity, 0) > 0.03
  AND so.requested_delivery_date BETWEEN (now() AT TIME ZONE 'Asia/Seoul')::date AND (now() AT TIME ZONE 'Asia/Seoul')::date + 7;

-- 재공(WIP) — 로트 상태별. 마감(CLOSING)·폐기(SCRAP) 로트는 재공이 아니다 (리뷰 F23, 공통코드 LotState 기준)
CREATE OR REPLACE VIEW mart.v_kpi_wip WITH (security_invoker = true) AS
SELECT enterprise_id, plant_id, current_operation_id, lot_state,
       count(*) AS lot_count, sum(lot_created_quantity) AS wip_qty,
       count(*) FILTER (WHERE hold_indicator) AS hold_lots
FROM ksx.lot
WHERE upper(coalesce(lot_state, '')) NOT IN ('CLOSING', 'SCRAP')
GROUP BY 1,2,3,4;
