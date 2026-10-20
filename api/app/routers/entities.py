from fastapi import APIRouter, Depends, HTTPException, Query

from ..db import audit
from ..deps import Scoped, scoped

router = APIRouter(prefix="/api", tags=["entities"])

DATA_IRI = "https://data.impix.co.kr/{ent}/{cls}/{id}"


@router.get("/lots/{lot_id}")
def lot(lot_id: str, s: Scoped = Depends(scoped)):
    c = s.conn
    row = c.execute(
        "SELECT l.*, i.item_name, o.operation_name AS current_operation_name"
        "  FROM ksx.lot l"
        "  LEFT JOIN ksx.item_master i ON i.enterprise_id = l.enterprise_id AND i.item_id = l.item_id"
        "  LEFT JOIN ksx.operation o ON o.enterprise_id = l.enterprise_id AND o.operation_id = l.current_operation_id"
        " WHERE l.lot_id = %s", (lot_id,)).fetchone()
    if row is None:
        raise HTTPException(404, f"로트 {lot_id} 가 없거나 볼 수 있는 범위 밖입니다")
    iri = DATA_IRI.format(ent=row["enterprise_id"], cls="lot", id=lot_id)
    ancestors = c.execute(
        "SELECT ancestor_lot_id AS lot_id, depth FROM mart.v_lot_genealogy WHERE lot_id = %s ORDER BY depth", (lot_id,)).fetchall()
    descendants = c.execute(
        "SELECT lot_id, depth FROM mart.v_lot_genealogy WHERE ancestor_lot_id = %s ORDER BY depth, lot_id", (lot_id,)).fetchall()
    spec_outs = c.execute(
        "SELECT equipment_id, parameter_id, parameter_name, event_date_time, parameter_value, lsl, usl"
        "  FROM mart.v_spec_out_lot WHERE lot_id = %s ORDER BY event_date_time", (lot_id,)).fetchall()
    defects = c.execute(
        "SELECT operation_id, defect_type_code, defect_type_detail_code, sum(defect_type_quantity) AS qty"
        "  FROM ksx.production_performance_quality WHERE lot_id = %s GROUP BY 1, 2, 3 ORDER BY qty DESC", (lot_id,)).fetchall()
    orders = c.execute(
        "SELECT so.sales_document_number AS sales_order_id, so.sales_document_sequence, sh.customer_id, cu.customer_name,"
        "       so.requested_delivery_date, so.item_quantity"
        "  FROM ksx.production_order po"
        "  JOIN ksx.sales_order_line so ON so.enterprise_id = po.enterprise_id AND so.sales_document_number = po.sales_document_number"
        "   AND so.sales_document_sequence = po.sales_document_sequence"
        "  LEFT JOIN ksx.sales_order_header sh ON sh.enterprise_id = so.enterprise_id AND sh.sales_document_number = so.sales_document_number"
        "  LEFT JOIN ksx.customer_party_master cu ON cu.enterprise_id = sh.enterprise_id AND cu.customer_id = sh.customer_id"
        " WHERE po.enterprise_id = %s AND po.production_order_id = %s AND po.production_order_sequence = %s",
        (row["enterprise_id"], row["production_order_id"], row["production_order_sequence"])).fetchall()
    risks = c.execute(
        "SELECT event_id, event_class_iri, risk_level, detail, detected_at, status FROM sem.risk_event"
        " WHERE source_iri = %s OR %s = ANY (affected_iris) ORDER BY detected_at DESC", (iri, iri)).fetchall()
    actions = c.execute(
        "SELECT e.execution_id, e.action_iri, a.label_ko AS action_label, e.status, e.requested_by, e.approved_by, e.created_at"
        "  FROM gov.action_execution e JOIN onto.action a ON a.action_iri = e.action_iri"
        " WHERE e.target_iri = %s ORDER BY e.created_at DESC", (iri,)).fetchall()
    audit(c, "read", f"ksx.lot:{lot_id}")
    return {"iri": iri, "lot": row, "ancestors": ancestors, "descendants": descendants, "spec_outs": spec_outs,
            "defects": defects, "orders": orders, "risks": risks, "actions": actions}


@router.get("/equipment/{equipment_id}")
def equipment(equipment_id: str, days: int = Query(default=7, ge=1, le=90), s: Scoped = Depends(scoped)):
    c = s.conn
    row = c.execute(
        "SELECT e.*, o.operation_name FROM ksx.equipment e"
        "  LEFT JOIN ksx.operation o ON o.enterprise_id = e.enterprise_id AND o.operation_id = e.operation_id"
        " WHERE e.equipment_id = %s", (equipment_id,)).fetchone()
    if row is None:
        raise HTTPException(404, f"설비 {equipment_id} 가 없거나 볼 수 있는 범위 밖입니다")
    params = c.execute(
        "SELECT parameter_id, parameter_name, parameter_uom_code, lsl, usl FROM ksx.equipment_parameter"
        " WHERE enterprise_id = %s AND equipment_id = %s ORDER BY parameter_id", (row["enterprise_id"], equipment_id)).fetchall()
    trace = c.execute(
        "SELECT parameter_id, event_date_time, parameter_value, validation_result_code FROM ksx.trace_parameter"
        " WHERE enterprise_id = %s AND equipment_id = %s"
        "   AND event_date_time >= (now() AT TIME ZONE 'Asia/Seoul') - make_interval(days => %s)"
        " ORDER BY event_date_time", (row["enterprise_id"], equipment_id, days)).fetchall()
    audit(c, "read", f"ksx.equipment:{equipment_id}")
    return {"equipment": row, "parameters": params, "trace": trace}
