"""데이터 관리(관리자용) 화면 API — 오늘의 레이크, 카탈로그, 온톨로지, 계보, 품질, 권한·감사.

관리 역할(admin·data_steward·data_engineer·ontology_manager) 중 하나가 있어야 한다.
행 범위는 다른 API 와 같이 RLS 가 거른다. 사용자·역할 목록은 admin 만 (gov.admin_role_assignments).
"""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from ..deps import Scoped, scoped

ADMIN_ROLES = {"admin", "data_steward", "data_engineer", "ontology_manager", "quality_engineer"}


def admin_scoped(s: Scoped = Depends(scoped)) -> Scoped:
    if not ADMIN_ROLES & set(s.user.roles):
        raise HTTPException(403, "데이터 관리 화면은 관리 역할(관리자·스튜어드·엔지니어·온톨로지 관리자·품질 엔지니어)이 있어야 볼 수 있습니다")
    return s


router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.get("/overview")
def overview(s: Scoped = Depends(admin_scoped)):
    c = s.conn
    zones = c.execute(
        "SELECT z.zone_id, z.label_ko, z.zone_order, count(d.dataset_id) AS datasets, sum(d.record_count) AS records"
        "  FROM catalog.zone z LEFT JOIN catalog.dataset d ON d.zone_id = z.zone_id"
        " GROUP BY z.zone_id, z.label_ko, z.zone_order ORDER BY z.zone_order").fetchall()
    pipelines = c.execute(
        "SELECT p.pipeline_id, p.label_ko, p.from_zone, p.to_zone, p.engine, p.schedule_cron, p.enabled, p.owner_user_id,"
        "       r.status AS last_status, r.started_at AS last_started_at, r.ended_at AS last_ended_at,"
        "       r.rows_in, r.rows_out, r.rows_rejected, r.error_message"
        "  FROM catalog.pipeline p"
        "  LEFT JOIN LATERAL (SELECT * FROM catalog.job_run j WHERE j.pipeline_id = p.pipeline_id"
        "                      ORDER BY j.started_at DESC LIMIT 1) r ON TRUE"
        " ORDER BY p.from_zone, p.pipeline_id").fetchall()
    counts = c.execute(
        "SELECT (SELECT count(*) FROM catalog.dataset) AS datasets,"
        "       (SELECT count(*) FROM onto.class) AS classes,"
        "       (SELECT count(*) FROM onto.property) AS properties,"
        "       (SELECT count(*) FROM catalog.quality_violation WHERE status = 'OPEN') AS open_violations,"
        "       (SELECT count(*) FROM gov.access_request WHERE status = 'REQUESTED') AS pending_access,"
        "       (SELECT count(*) FROM sem.risk_event WHERE status = 'OPEN') AS open_risks").fetchone()
    risks = c.execute(
        "SELECT event_id, risk_level, source_iri, detail, detected_at, derived_by FROM sem.risk_event"
        " WHERE status = 'OPEN' ORDER BY detected_at DESC LIMIT 10").fetchall()
    return {"counts": counts, "zones": zones, "pipelines": pipelines, "risks": risks}


@router.get("/datasets")
def datasets(q: str | None = Query(default=None, max_length=100), zone: str | None = None,
             s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT d.dataset_id, d.title_ko, d.zone_id, d.represents_class_iri, c.label_ko AS class_label, d.source_system_id,"
        "       d.location_uri, d.format, d.ingest_mode, d.record_count, d.last_ingested_at, d.quality_score,"
        "       d.quality_status, d.sensitivity, d.tags"
        "  FROM catalog.dataset d LEFT JOIN onto.class c ON c.class_iri = d.represents_class_iri"
        " WHERE (%(q)s::text IS NULL OR d.dataset_id ILIKE '%%' || %(q)s || '%%' OR d.title_ko ILIKE '%%' || %(q)s || '%%')"
        "   AND (%(z)s::text IS NULL OR d.zone_id = %(z)s)"
        " ORDER BY d.zone_id, d.dataset_id", {"q": q, "z": zone}).fetchall()


@router.get("/datasets/{dataset_id}")
def dataset(dataset_id: str, s: Scoped = Depends(admin_scoped)):
    c = s.conn
    d = c.execute(
        "SELECT d.*, c.label_ko AS class_label, ss.label_ko AS source_label, ss.system_type"
        "  FROM catalog.dataset d LEFT JOIN onto.class c ON c.class_iri = d.represents_class_iri"
        "  LEFT JOIN catalog.source_system ss ON ss.source_system_id = d.source_system_id"
        " WHERE d.dataset_id = %s", (dataset_id,)).fetchone()
    if d is None:
        raise HTTPException(404, f"데이터셋 {dataset_id} 가 없거나 볼 수 있는 범위 밖입니다")
    fields = c.execute("SELECT * FROM catalog.dataset_field WHERE dataset_id = %s ORDER BY 2", (dataset_id,)).fetchall()
    upstream = c.execute(
        "SELECT e.from_dataset_id AS dataset_id, e.pipeline_id, e.relation, e.field_map FROM catalog.lineage_edge e"
        " WHERE e.to_dataset_id = %s ORDER BY 1", (dataset_id,)).fetchall()
    downstream = c.execute(
        "SELECT e.to_dataset_id AS dataset_id, e.pipeline_id, e.relation FROM catalog.lineage_edge e"
        " WHERE e.from_dataset_id = %s ORDER BY 1", (dataset_id,)).fetchall()
    mappings = c.execute("SELECT * FROM catalog.mapping WHERE source_dataset_id = %s ORDER BY version_no DESC",
                         (dataset_id,)).fetchall()
    quality = c.execute(
        "SELECT quality_run_id, executed_at, focus_count, violation_count, conformance_rate FROM catalog.quality_run"
        " WHERE dataset_id = %s ORDER BY executed_at DESC LIMIT 10", (dataset_id,)).fetchall()
    # 이 데이터셋에 돈 규칙마다 최신 실행 하나 — 데이터셋 품질 점수·상태는 이것들을 종합한 값이다 (V0015)
    quality_rules = c.execute(
        "SELECT DISTINCT ON (q.rule_id) q.rule_id, r.label_ko, r.dimension, r.severity, r.threshold, r.enabled,"
        "       q.executed_at, q.focus_count, q.violation_count, q.conformance_rate"
        "  FROM catalog.quality_run q JOIN catalog.quality_rule r ON r.rule_id = q.rule_id"
        " WHERE q.dataset_id = %s ORDER BY q.rule_id, q.executed_at DESC", (dataset_id,)).fetchall()
    quality_rules.sort(key=lambda x: (not x["enabled"], x["conformance_rate"] if x["conformance_rate"] is not None else 101))
    return {"dataset": d, "fields": fields, "upstream": upstream, "downstream": downstream,
            "mappings": mappings, "quality_runs": quality, "quality_rules": quality_rules}


@router.get("/ontology/classes")
def classes(q: str | None = Query(default=None, max_length=100), s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT c.class_iri, c.local_name, c.label_ko, c.label_en, c.business_group, c.parent_class_iri,"
        "       c.standard_clause, c.physical_table, c.is_event, c.is_standard,"
        "       (SELECT count(*) FROM catalog.dataset d WHERE d.represents_class_iri = c.class_iri) AS datasets"
        "  FROM onto.class c"
        " WHERE %(q)s::text IS NULL OR c.label_ko ILIKE '%%' || %(q)s || '%%' OR c.local_name ILIKE '%%' || %(q)s || '%%'"
        " ORDER BY c.business_group NULLS LAST, c.label_ko", {"q": q}).fetchall()


@router.get("/ontology/classes/{local_name}")
def ontology_class(local_name: str, s: Scoped = Depends(admin_scoped)):
    c = s.conn
    cls = c.execute("SELECT * FROM onto.class WHERE local_name = %s ORDER BY is_standard DESC LIMIT 1",
                    (local_name,)).fetchone()
    if cls is None:
        raise HTTPException(404, f"클래스 {local_name} 가 없습니다")
    iri = cls["class_iri"]
    links = c.execute(
        "SELECT l.property_iri, p.label_ko AS property_label, p.local_name AS property_name, l.relation_kind, l.fk_columns,"
        "       l.subject_class_iri, sc.label_ko AS subject_label, l.object_class_iri, oc.label_ko AS object_label"
        "  FROM onto.link l JOIN onto.property p ON p.property_iri = l.property_iri"
        "  JOIN onto.class sc ON sc.class_iri = l.subject_class_iri JOIN onto.class oc ON oc.class_iri = l.object_class_iri"
        " WHERE l.subject_class_iri = %s OR l.object_class_iri = %s ORDER BY p.local_name", (iri, iri)).fetchall()
    datasets_ = c.execute("SELECT dataset_id, title_ko, zone_id FROM catalog.dataset WHERE represents_class_iri = %s",
                          (iri,)).fetchall()
    actions = c.execute("SELECT action_iri, label_ko, verb FROM onto.action WHERE target_class_iri = %s", (iri,)).fetchall()
    rules = c.execute("SELECT rule_id, label_ko, dimension, severity FROM catalog.quality_rule WHERE target_class_iri = %s",
                      (iri,)).fetchall()
    return {"class": cls, "links": links, "datasets": datasets_, "actions": actions, "quality_rules": rules}


@router.get("/lineage")
def lineage(s: Scoped = Depends(admin_scoped)):
    c = s.conn
    edges = c.execute(
        "SELECT e.edge_id, e.from_dataset_id, f.zone_id AS from_zone, f.title_ko AS from_title,"
        "       e.to_dataset_id, t.zone_id AS to_zone, t.title_ko AS to_title, e.pipeline_id, p.label_ko AS pipeline_label,"
        "       e.relation, e.field_map"
        "  FROM catalog.lineage_edge e"
        "  JOIN catalog.dataset f ON f.dataset_id = e.from_dataset_id"
        "  JOIN catalog.dataset t ON t.dataset_id = e.to_dataset_id"
        "  LEFT JOIN catalog.pipeline p ON p.pipeline_id = e.pipeline_id"
        " ORDER BY f.zone_id, e.from_dataset_id").fetchall()
    return {"edges": edges}


@router.get("/quality")
def quality(s: Scoped = Depends(admin_scoped)):
    c = s.conn
    rules = c.execute(
        "SELECT r.rule_id, r.label_ko, r.dimension, r.target_class_iri, cl.label_ko AS class_label, r.target_dataset_id,"
        "       r.shape_iri, r.sql_check, r.severity, r.threshold, r.enabled,"
        "       q.dataset_id AS last_dataset_id, q.executed_at AS last_run_at, q.focus_count, q.violation_count, q.conformance_rate"
        "  FROM catalog.quality_rule r LEFT JOIN onto.class cl ON cl.class_iri = r.target_class_iri"
        "  LEFT JOIN LATERAL (SELECT qr.* FROM catalog.quality_run qr WHERE qr.rule_id = r.rule_id"   # 위반 0건 실행도 최근 결과로 (V0013)
        "                     ORDER BY qr.executed_at DESC LIMIT 1) q ON TRUE"
        " ORDER BY r.rule_id").fetchall()
    violations = c.execute(
        "SELECT v.violation_id, v.rule_id, v.focus_node, v.result_path, v.message, v.severity, v.status,"
        "       v.assignee_user_id, q.dataset_id, q.executed_at"
        "  FROM catalog.quality_violation v JOIN catalog.quality_run q ON q.quality_run_id = v.quality_run_id"
        " ORDER BY q.executed_at DESC, v.violation_id LIMIT 200").fetchall()
    # 품질 부적합이라 시맨틱 존 반영이 막힌 원천 (gov.semantic_gate 가 파이프라인 시작을 거절한다)
    blocked = c.execute("SELECT * FROM gov.semantic_blockers()").fetchall()
    return {"rules": rules, "violations": violations, "semantic_blocked": blocked}


@router.get("/access")
def access(s: Scoped = Depends(admin_scoped)):
    c = s.conn
    requests = c.execute(
        "SELECT a.request_id, a.requester_id, a.dataset_id, d.title_ko AS dataset_title, d.sensitivity, a.purpose,"
        "       a.requested_actions, a.period_from, a.period_to, a.status, a.approver_id, a.decided_at, a.decision_note, a.created_at"
        "  FROM gov.access_request a LEFT JOIN catalog.dataset d ON d.dataset_id = a.dataset_id"
        " ORDER BY (a.status = 'REQUESTED') DESC, a.created_at DESC LIMIT 100").fetchall()
    roles = c.execute("SELECT role_id, label_ko, description FROM gov.role ORDER BY role_id").fetchall()
    assignments = None
    if "admin" in s.user.roles:
        assignments = c.execute("SELECT * FROM gov.admin_role_assignments()").fetchall()
    return {"requests": requests, "roles": roles, "assignments": assignments}


@router.get("/audit")
def audit_log(limit: int = Query(default=100, ge=1, le=500), action: str | None = None,
              s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT occurred_at, user_id, channel, action, dataset_id, object_ref, left(query_text, 300) AS query_text,"
        "       row_count, result FROM gov.audit_log"
        " WHERE %(a)s::text IS NULL OR action = %(a)s ORDER BY occurred_at DESC LIMIT %(n)s",
        {"a": action, "n": limit}).fetchall()


class Decision(BaseModel):
    approve: bool
    note: str | None = Field(default=None, max_length=1000)


@router.post("/access/{request_id}/decision")
def decide_access(request_id: UUID, body: Decision, s: Scoped = Depends(admin_scoped)):
    status = s.conn.execute("SELECT gov.decide_access_request(%s, %s, %s) AS status",
                            (request_id, body.approve, body.note)).fetchone()["status"]
    return {"request_id": request_id, "status": status}
