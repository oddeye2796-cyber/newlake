from dataclasses import asdict

from fastapi import APIRouter, Depends, Query

from ..deps import Scoped, scoped

router = APIRouter(prefix="/api", tags=["core"])


@router.get("/me")
def me(s: Scoped = Depends(scoped)):
    return asdict(s.user)


@router.get("/home")
def home(s: Scoped = Depends(scoped)):
    """첫 화면: 열린 리스크, 승인 대기, 최근 규격 이탈, KPI 요약."""
    c = s.conn
    risks = c.execute(
        "SELECT event_id, event_class_iri, risk_level, source_iri, affected_iris, detail, detected_at, status"
        "  FROM sem.risk_event WHERE status = 'OPEN'"
        " ORDER BY CASE risk_level WHEN 'CRITICAL' THEN 0 WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, detected_at DESC"
        " LIMIT 20").fetchall()
    pending = c.execute("SELECT count(*) AS n FROM gov.action_execution WHERE status = 'PROPOSED'").fetchone()["n"]
    spec_outs = c.execute(
        "SELECT equipment_id, parameter_id, parameter_name, event_date_time, parameter_value, lsl, usl, lot_id, operation_id"
        "  FROM mart.v_spec_out_lot ORDER BY event_date_time DESC LIMIT 10").fetchall()
    kpi = c.execute(
        "SELECT"
        " (SELECT round(100 * (1 - sum(defect_qty) / nullif(sum(produced_qty), 0)), 2) FROM mart.v_kpi_yield_daily"
        "   WHERE perf_date >= (now() AT TIME ZONE 'Asia/Seoul')::date - 7) AS yield_7d_pct,"
        " (SELECT round(100.0 * count(*) FILTER (WHERE on_time) / nullif(count(on_time), 0), 1) FROM mart.v_kpi_otd) AS otd_pct,"
        " (SELECT coalesce(sum(lot_count), 0) FROM mart.v_kpi_wip) AS wip_lots,"
        " (SELECT coalesce(sum(hold_lots), 0) FROM mart.v_kpi_wip) AS hold_lots").fetchone()
    return {"risks": risks, "pending_approvals": pending, "spec_outs": spec_outs, "kpi": kpi}


@router.get("/search")
def search(q: str = Query(min_length=1, max_length=100), s: Scoped = Depends(scoped)):
    """로트·설비·수주·품목·고객 ID/이름 검색 (범위 안에서만)."""
    pat = f"%{q}%"
    rows = s.conn.execute(
        """
        SELECT 'lot' AS kind, lot_id AS id, coalesce(lot_name, lot_id) AS label, lot_state AS sub FROM ksx.lot
         WHERE lot_id ILIKE %(p)s OR lot_name ILIKE %(p)s
        UNION ALL
        SELECT 'equipment', equipment_id, equipment_name, operation_id FROM ksx.equipment
         WHERE equipment_id ILIKE %(p)s OR equipment_name ILIKE %(p)s
        UNION ALL
        SELECT 'order', sales_document_number, sales_document_number || coalesce(' · ' || customer_id, ''), sales_date::text FROM ksx.sales_order_header
         WHERE sales_document_number ILIKE %(p)s OR customer_id ILIKE %(p)s
        UNION ALL
        SELECT 'item', item_id, item_name, item_uom_code FROM ksx.item_master
         WHERE item_id ILIKE %(p)s OR item_name ILIKE %(p)s
        UNION ALL
        SELECT 'customer', customer_id, customer_name, NULL FROM ksx.customer_party_master
         WHERE customer_id ILIKE %(p)s OR customer_name ILIKE %(p)s
        ORDER BY 1, 2 LIMIT 30
        """, {"p": pat}).fetchall()
    return {"q": q, "results": rows}


@router.get("/catalog/datasets")
def datasets(s: Scoped = Depends(scoped)):
    return s.conn.execute(
        "SELECT dataset_id, title_ko, zone_id, represents_class_iri, source_system_id, location_uri, format,"
        "       ingest_mode, record_count, sensitivity FROM catalog.dataset ORDER BY zone_id, dataset_id").fetchall()
