"""권한·운영 CRUD — 사용자, 역할 배정·범위, 접근 정책, 조치 정책 (admin 전용), 접근 요청 만들기·취소 (누구나), 적재 배치 지우기.

쓰기는 모두 gov.* SECURITY DEFINER 함수로만 하고, 함수가 역할을 다시 확인하며 감사 기록을 남긴다.
"""
import json
from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..deps import Scoped, scoped
from .admin import admin_scoped

router = APIRouter(prefix="/api", tags=["gov"])

ACTIONS = ("read", "query", "download", "export")


def only_admin(s: Scoped = Depends(admin_scoped)) -> Scoped:
    if "admin" not in s.user.roles:
        raise HTTPException(403, "플랫폼 관리자(admin)만 할 수 있습니다")
    return s


# ── 사용자 ──────────────────────────────────────────────────────────────────

class UserIn(BaseModel):
    display_name: str = Field(min_length=1, max_length=100)
    email: str | None = Field(default=None, max_length=200)
    personnel_id: str | None = Field(default=None, max_length=50)
    status: str = "ACTIVE"


@router.get("/admin/users")
def users(s: Scoped = Depends(only_admin)):
    return s.conn.execute("SELECT * FROM gov.admin_users()").fetchall()


@router.put("/admin/users/{user_id}")
def save_user(user_id: str, body: UserIn, s: Scoped = Depends(only_admin)):
    if body.status not in ("ACTIVE", "LOCKED", "RETIRED"):
        raise HTTPException(400, "상태가 올바르지 않습니다")
    uid = s.conn.execute("SELECT gov.save_user(%s, %s, %s, %s, %s) AS id",
                         (user_id, body.display_name, body.email, body.personnel_id, body.status)).fetchone()["id"]
    return {"user_id": uid}


# ── 역할 배정 ───────────────────────────────────────────────────────────────

class GrantIn(BaseModel):
    user_id: str = Field(max_length=50)
    role_id: str = Field(max_length=40)
    site_id: str | None = Field(default=None, max_length=50)
    plant_id: str | None = Field(default=None, max_length=50)
    valid_until: date | None = None


class RevokeIn(BaseModel):
    user_id: str = Field(max_length=50)
    role_id: str = Field(max_length=40)
    site_id: str | None = Field(default=None, max_length=50)
    plant_id: str | None = Field(default=None, max_length=50)


@router.post("/admin/roles/grant")
def grant_role(body: GrantIn, s: Scoped = Depends(only_admin)):
    s.conn.execute("SELECT gov.grant_role(%s, %s, %s, %s, %s)",
                   (body.user_id, body.role_id, body.site_id or None, body.plant_id or None, body.valid_until))
    return {"ok": True}


@router.post("/admin/roles/revoke")
def revoke_role(body: RevokeIn, s: Scoped = Depends(only_admin)):
    s.conn.execute("SELECT gov.revoke_role(%s, %s, %s, %s)", (body.user_id, body.role_id, body.site_id or None, body.plant_id or None))
    return {"ok": True}


@router.get("/admin/scopes")
def scopes(s: Scoped = Depends(admin_scoped)):
    """역할 범위를 고를 때 쓰는 사업장·공장 목록."""
    return {"sites": s.conn.execute("SELECT site_id, site_name FROM ksx.site ORDER BY site_id").fetchall(),
            "plants": s.conn.execute("SELECT plant_id, site_id, plant_name FROM ksx.plant ORDER BY site_id, plant_id").fetchall()}


# ── 접근 정책 ───────────────────────────────────────────────────────────────

class AccessPolicyIn(BaseModel):
    role_id: str = Field(max_length=40)
    target_class_iri: str | None = Field(default=None, max_length=300)
    target_dataset_id: str | None = Field(default=None, max_length=150)
    max_sensitivity: str = "INTERNAL"
    actions: list[str] = ["read"]
    requires_approval: bool = False


@router.get("/admin/access-policies")
def access_policies(s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT p.policy_id, p.role_id, r.label_ko AS role_label, p.target_class_iri, c.label_ko AS class_label,"
        "       p.target_dataset_id, d.title_ko AS dataset_title, p.max_sensitivity, p.actions, p.requires_approval"
        "  FROM gov.access_policy p JOIN gov.role r ON r.role_id = p.role_id"
        "  LEFT JOIN onto.class c ON c.class_iri = p.target_class_iri"
        "  LEFT JOIN catalog.dataset d ON d.dataset_id = p.target_dataset_id"
        " ORDER BY p.role_id, p.policy_id").fetchall()


@router.put("/admin/access-policies/{policy_id}")
def save_access_policy(policy_id: str, body: AccessPolicyIn, s: Scoped = Depends(only_admin)):
    if any(a not in ACTIONS for a in body.actions) or not body.actions:
        raise HTTPException(400, "허용 행위가 올바르지 않습니다")
    pid = s.conn.execute("SELECT gov.save_access_policy(%s, %s, %s, %s, %s, %s, %s) AS id",
                         (policy_id, body.role_id, body.target_class_iri, body.target_dataset_id, body.max_sensitivity,
                          body.actions, body.requires_approval)).fetchone()["id"]
    return {"policy_id": pid}


@router.delete("/admin/access-policies/{policy_id}")
def delete_access_policy(policy_id: str, s: Scoped = Depends(only_admin)):
    s.conn.execute("SELECT gov.delete_access_policy(%s)", (policy_id,))
    return {"ok": True}


# ── 조치 정책 ───────────────────────────────────────────────────────────────

class ActionPolicyIn(BaseModel):
    trigger_class_iri: str = Field(max_length=300)
    condition: dict = {}
    action_iri: str = Field(max_length=300)
    mode: str = "approval"
    approver_role_id: str | None = Field(default=None, max_length=40)
    notify_role_ids: list[str] = []
    suppress_minutes: int = Field(default=240, ge=0, le=100000)
    enabled: bool = True


@router.get("/admin/action-policies")
def action_policies(s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT p.policy_id, p.trigger_class_iri, c.label_ko AS trigger_label, p.condition, p.action_iri, a.label_ko AS action_label,"
        "       p.mode, p.approver_role_id, p.notify_role_ids, extract(epoch FROM p.suppress_window)::int / 60 AS suppress_minutes, p.enabled,"
        "       (SELECT count(*) FROM gov.action_execution e WHERE e.policy_id = p.policy_id) AS executions"
        "  FROM gov.action_policy p LEFT JOIN onto.class c ON c.class_iri = p.trigger_class_iri"
        "  LEFT JOIN onto.action a ON a.action_iri = p.action_iri"
        " ORDER BY p.policy_id").fetchall()


@router.get("/admin/ontology/actions")
def ontology_actions(s: Scoped = Depends(admin_scoped)):
    return s.conn.execute("SELECT action_iri, label_ko FROM onto.action ORDER BY label_ko").fetchall()


@router.put("/admin/action-policies/{policy_id}")
def save_action_policy(policy_id: str, body: ActionPolicyIn, s: Scoped = Depends(only_admin)):
    pid = s.conn.execute("SELECT gov.save_action_policy(%s, %s, %s::jsonb, %s, %s, %s, %s, %s, %s) AS id",
                         (policy_id, body.trigger_class_iri, json.dumps(body.condition), body.action_iri, body.mode,
                          body.approver_role_id, body.notify_role_ids, body.suppress_minutes, body.enabled)).fetchone()["id"]
    return {"policy_id": pid}


@router.delete("/admin/action-policies/{policy_id}")
def delete_action_policy(policy_id: str, s: Scoped = Depends(only_admin)):
    s.conn.execute("SELECT gov.delete_action_policy(%s)", (policy_id,))
    return {"ok": True}


# ── 접근 요청 (누구나) ─────────────────────────────────────────────────────

class AccessRequestIn(BaseModel):
    dataset_id: str = Field(max_length=150)
    purpose: str = Field(min_length=5, max_length=1000)
    actions: list[str] = ["read"]
    period_from: date
    period_to: date


@router.get("/access-requests")
def my_access_requests(s: Scoped = Depends(scoped)):
    return s.conn.execute("SELECT * FROM gov.my_access_requests()").fetchall()


@router.post("/access-requests")
def create_access_request(body: AccessRequestIn, s: Scoped = Depends(scoped)):
    if any(a not in ACTIONS for a in body.actions) or not body.actions:
        raise HTTPException(400, "요청 행위가 올바르지 않습니다")
    rid = s.conn.execute("SELECT gov.create_access_request(%s, %s, %s, %s, %s) AS id",
                         (body.dataset_id, body.purpose, body.actions, body.period_from, body.period_to)).fetchone()["id"]
    return {"request_id": rid}


@router.delete("/access-requests/{request_id}")
def cancel_access_request(request_id: UUID, s: Scoped = Depends(scoped)):
    st = s.conn.execute("SELECT gov.cancel_access_request(%s) AS st", (request_id,)).fetchone()["st"]
    return {"request_id": request_id, "status": st}


# ── 적재 배치 지우기 ───────────────────────────────────────────────────────

@router.delete("/admin/batches/{batch_id}")
def delete_batch(batch_id: UUID, s: Scoped = Depends(admin_scoped)):
    return s.conn.execute("SELECT gov.delete_batch(%s) AS r", (batch_id,)).fetchone()["r"]
