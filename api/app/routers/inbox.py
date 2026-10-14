from uuid import UUID

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from ..deps import Scoped, scoped

router = APIRouter(prefix="/api/inbox", tags=["inbox"])


class Decision(BaseModel):
    approve: bool
    note: str | None = Field(default=None, max_length=1000)


@router.get("")
def inbox(status: str = "PROPOSED", s: Scoped = Depends(scoped)):
    """status=ALL 이면 처리된 것까지 전부."""
    rows = s.conn.execute(
        "SELECT e.execution_id, e.policy_id, e.action_iri, a.label_ko AS action_label, e.target_iri, e.site_id, e.plant_id,"
        "       e.status, e.requested_by, e.approved_by, e.rationale, e.created_at,"
        "       p.approver_role_id, r.risk_level, r.detail AS risk_detail"
        "  FROM gov.action_execution e"
        "  JOIN onto.action a ON a.action_iri = e.action_iri"
        "  LEFT JOIN gov.action_policy p ON p.policy_id = e.policy_id"
        "  LEFT JOIN sem.risk_event r ON r.event_id = e.risk_event_id"
        " WHERE %s = 'ALL' OR e.status = %s ORDER BY e.created_at DESC LIMIT 100", (status.upper(), status.upper())).fetchall()
    roles = set(s.user.roles)
    for r in rows:
        # 화면용 힌트. 최종 판정(역할 + 범위)은 gov.decide_action 이 한다.
        r["can_decide"] = r["status"] == "PROPOSED" and bool(roles & {r["approver_role_id"] or "admin", "admin"})
    return rows


@router.post("/{execution_id}/decision")
def decide(execution_id: UUID, body: Decision, s: Scoped = Depends(scoped)):
    status = s.conn.execute("SELECT gov.decide_action(%s, %s, %s) AS status",
                            (execution_id, body.approve, body.note)).fetchone()["status"]
    return {"execution_id": execution_id, "status": status}
