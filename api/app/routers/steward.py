"""데이터 스튜어드십 CRUD — 데이터셋 메타·필드, 매핑 승인, 품질 규칙·바로 실행·위반 처리, 위험 닫기, 파이프라인 켜기/끄기.

쓰기는 모두 gov.* SECURITY DEFINER 함수로만 하고, 함수가 역할(gov.require_role)을 다시 확인하며 감사 기록을 남긴다.
품질 검사식(sql_check)만 예외로 API 가 lake_agent(읽기 전용·RLS)로 실행하고 결과를 gov.record_quality_run 에 넘긴다.
"""
import json
import re
from uuid import UUID

import psycopg
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..db import agent_transaction
from ..deps import Scoped, scoped
from .admin import admin_scoped

router = APIRouter(prefix="/api/admin", tags=["steward"])

SENSITIVITY = ("PUBLIC", "INTERNAL", "CONFIDENTIAL", "PERSONAL")
DIMENSIONS = ("완전성", "유일성", "유효성", "일관성", "정확성", "구조", "값", "관계", "의미")
SEVERITIES = ("Info", "Warning", "Violation")
_TABLE = re.compile(r"^postgresql://lake/([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)$")


@router.get("/people")
def people(s: Scoped = Depends(admin_scoped)):
    """소유자·스튜어드·담당자를 고를 때 쓰는 사용자 목록 (admin 전용 사용자 관리와 달리 이름만)."""
    return s.conn.execute("SELECT user_id, display_name FROM gov.app_user WHERE status = 'ACTIVE' ORDER BY display_name").fetchall()


@router.get("/ontology/properties")
def properties(s: Scoped = Depends(admin_scoped)):
    """필드에 온톨로지 속성을 붙일 때 쓰는 목록."""
    return s.conn.execute(
        "SELECT property_iri, local_name, kind, label_ko, range_iri FROM onto.property ORDER BY kind, local_name").fetchall()


# ── 데이터셋 메타 ───────────────────────────────────────────────────────────

class DatasetIn(BaseModel):
    title_ko: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    sensitivity: str = "INTERNAL"
    pseudonymized: bool = False
    retention: str | None = Field(default=None, max_length=50)
    owner_user_id: str | None = Field(default=None, max_length=50)
    steward_user_id: str | None = Field(default=None, max_length=50)
    tags: list[str] = []


@router.put("/datasets/{dataset_id}")
def update_dataset(dataset_id: str, body: DatasetIn, s: Scoped = Depends(admin_scoped)):
    if body.sensitivity not in SENSITIVITY:
        raise HTTPException(400, "민감도가 올바르지 않습니다")
    tags = [t.strip() for t in body.tags if t.strip()][:30]
    s.conn.execute("SELECT gov.update_dataset(%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                   (dataset_id, body.title_ko, body.description, body.sensitivity, body.pseudonymized, body.retention,
                    body.owner_user_id, body.steward_user_id, tags))
    return {"dataset_id": dataset_id}


@router.delete("/datasets/{dataset_id}")
def delete_dataset(dataset_id: str, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.delete_dataset(%s)", (dataset_id,))
    return {"dataset_id": dataset_id, "deleted": True}


# ── 필드 ────────────────────────────────────────────────────────────────────

class FieldIn(BaseModel):
    label_ko: str | None = Field(default=None, max_length=200)
    description: str | None = Field(default=None, max_length=1000)
    is_pii: bool = False
    maps_to_property_iri: str | None = Field(default=None, max_length=300)
    decision: str | None = None  # ACCEPT | REJECT | None(그냥 고치기)


@router.put("/datasets/{dataset_id}/fields/{field_name}")
def update_field(dataset_id: str, field_name: str, body: FieldIn, s: Scoped = Depends(admin_scoped)):
    if body.decision not in (None, "ACCEPT", "REJECT"):
        raise HTTPException(400, "결정은 ACCEPT 또는 REJECT 입니다")
    s.conn.execute("SELECT gov.update_field(%s, %s, %s, %s, %s, %s, %s)",
                   (dataset_id, field_name, body.label_ko, body.description, body.is_pii, body.maps_to_property_iri, body.decision))
    return s.conn.execute("SELECT * FROM catalog.dataset_field WHERE dataset_id = %s AND field_name = %s",
                          (dataset_id, field_name)).fetchone()


# ── 매핑 버전 상태 ──────────────────────────────────────────────────────────

class MappingStatusIn(BaseModel):
    mapping_id: str = Field(max_length=200)   # 경로에 '/'·'@' 가 들어가서 본문으로 받는다
    status: str


@router.post("/mappings/status")
def set_mapping_status(body: MappingStatusIn, s: Scoped = Depends(admin_scoped)):
    if body.status not in ("REVIEW", "APPROVED", "RETIRED"):
        raise HTTPException(400, "상태가 올바르지 않습니다")
    st = s.conn.execute("SELECT gov.set_mapping_status(%s, %s) AS st", (body.mapping_id, body.status)).fetchone()["st"]
    return {"mapping_id": body.mapping_id, "status": st}


# ── 품질 규칙 ───────────────────────────────────────────────────────────────

class RuleIn(BaseModel):
    label_ko: str = Field(min_length=1, max_length=200)
    dimension: str = "완전성"
    target_class_iri: str | None = Field(default=None, max_length=300)
    target_dataset_id: str | None = Field(default=None, max_length=150)
    shape_iri: str | None = Field(default=None, max_length=300)
    sql_check: str | None = Field(default=None, max_length=20000)
    severity: str = "Violation"
    threshold: float | None = Field(default=None, ge=0, le=100)
    enabled: bool = True


@router.put("/quality/rules/{rule_id}")
def save_rule(rule_id: str, body: RuleIn, s: Scoped = Depends(admin_scoped)):
    if body.dimension not in DIMENSIONS:
        raise HTTPException(400, "차원이 올바르지 않습니다")
    if body.severity not in SEVERITIES:
        raise HTTPException(400, "심각도가 올바르지 않습니다")
    rid = s.conn.execute("SELECT gov.save_quality_rule(%s, %s, %s, %s, %s, %s, %s, %s, %s::numeric, %s) AS id",
                         (rule_id, body.label_ko, body.dimension, body.target_class_iri, body.target_dataset_id, body.shape_iri,
                          body.sql_check, body.severity, body.threshold, body.enabled)).fetchone()["id"]
    return {"rule_id": rid}


@router.delete("/quality/rules/{rule_id}")
def delete_rule(rule_id: str, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.delete_quality_rule(%s)", (rule_id,))
    return {"rule_id": rule_id, "deleted": True}


class RunIn(BaseModel):
    dataset_id: str | None = Field(default=None, max_length=150)


def _check_rows(s: Scoped, sql_check: str, table: str | None, inline: bool) -> tuple[list[dict], int | None]:
    """검사식을 돌려 위반 행과 대상 표 행 수를 돌려준다.

    inline=False: lake_agent(읽기 전용·RLS) 연결로 돈다 — 바로 실행 버튼.
    inline=True: 지금 요청의 트랜잭션 안에서 돈다 — 적재 직후 자동 검증은 아직 커밋 전인 새 행을 봐야 한다.
      읽기 전용 세이브포인트(SET LOCAL transaction_read_only) 안에서 돌리고 끝나면 되돌려, 검사식이 무엇이든 쓰기는 못 한다.
    """
    if not inline:
        with agent_transaction(s.user) as ac:
            rows = ac.execute("SELECT gov.run_agent_query(%s, %s) AS rows", (sql_check, 5000)).fetchone()["rows"]
            focus = ac.execute(f"SELECT count(*) AS n FROM {table}").fetchone()["n"] if table else None
        return rows, focus
    out: dict = {}
    try:
        with s.conn.transaction():
            s.conn.execute("SET LOCAL transaction_read_only = on")
            s.conn.execute("SET LOCAL statement_timeout = 5000")
            cur = s.conn.execute(sql_check)
            out["rows"] = [dict(r) for r in cur.fetchmany(5000)] if cur.description else []
            out["focus"] = s.conn.execute(f"SELECT count(*) AS n FROM {table}").fetchone()["n"] if table else None
            raise psycopg.Rollback()
    except psycopg.Rollback:
        pass
    return out["rows"], out["focus"]


def run_rule_now(s: Scoped, rule: dict, dataset_id: str | None, inline: bool = False) -> dict:
    """검사식(SQL)을 지금 돌리고 gov.record_quality_run 으로 기록한다. 바로 실행 버튼과 적재 후 자동 검증이 함께 쓴다.

    rule: {rule_id, label_ko, sql_check, target_dataset_id}. 검사식은 위반 행을 돌려주는 SELECT 한 문장
    (열: focus_node, result_path, message — 없으면 첫 열을 focus_node 로).
    """
    dataset_id = dataset_id or rule["target_dataset_id"]
    ds = None
    if dataset_id:
        ds = s.conn.execute("SELECT dataset_id, location_uri, record_count FROM catalog.dataset WHERE dataset_id = %s", (dataset_id,)).fetchone()
        if ds is None:
            raise HTTPException(404, f"데이터셋 {dataset_id} 가 없습니다")
    m = _TABLE.match(ds["location_uri"] or "") if ds else None
    try:
        rows, focus = _check_rows(s, rule["sql_check"], m.group(1) if m else None, inline)
    except psycopg.Error as e:
        raise HTTPException(400, f"검사식 실행 실패: {e.diag.message_primary or e}")
    if focus is None:
        focus = ds["record_count"] if ds and ds["record_count"] is not None else len(rows)
    viol = []
    for r in rows:
        first = next(iter(r.values()), None) if r else None
        viol.append({"focus_node": str(r.get("focus_node") or first or "?"), "result_path": r.get("result_path"),
                     "message": r.get("message") or rule["label_ko"]})
    out = s.conn.execute("SELECT gov.record_quality_run(%s, %s, %s, %s::jsonb) AS r",
                         (rule["rule_id"], dataset_id, focus, json.dumps(viol, ensure_ascii=False, default=str))).fetchone()["r"]
    out["dataset_id"] = dataset_id
    out["rule_id"] = rule["rule_id"]
    out["label_ko"] = rule["label_ko"]
    return out


@router.post("/quality/rules/{rule_id}/run")
def run_rule(rule_id: str, body: RunIn | None = None, s: Scoped = Depends(admin_scoped)):
    """검사식을 지금 바로 돌린다."""
    rule = s.conn.execute("SELECT rule_id, label_ko, sql_check, target_dataset_id FROM catalog.quality_rule WHERE rule_id = %s", (rule_id,)).fetchone()
    if rule is None:
        raise HTTPException(404, f"규칙 {rule_id} 가 없습니다")
    if not rule["sql_check"]:
        raise HTTPException(409, "이 규칙에는 검사식(SQL)이 없어 바로 실행할 수 없습니다. SHACL 셰이프 규칙은 배치 파이프라인이 돌립니다")
    return run_rule_now(s, rule, body.dataset_id if body and body.dataset_id else None)


class ViolationIn(BaseModel):
    status: str
    assignee_user_id: str | None = Field(default=None, max_length=50)


@router.put("/quality/violations/{violation_id}")
def update_violation(violation_id: int, body: ViolationIn, s: Scoped = Depends(admin_scoped)):
    if body.status not in ("OPEN", "ACK", "FIXED", "WAIVED"):
        raise HTTPException(400, "상태가 올바르지 않습니다")
    s.conn.execute("SELECT gov.update_violation(%s, %s, %s)", (violation_id, body.status, body.assignee_user_id))
    return {"violation_id": violation_id, "status": body.status, "assignee_user_id": body.assignee_user_id}


# ── 위험 상태 (생산 관리자·품질 엔지니어·스튜어드: 관리 화면 밖에서도 가능) ──

class RiskStatusIn(BaseModel):
    status: str


@router.post("/risks/{event_id}/status")
def set_risk_status(event_id: UUID, body: RiskStatusIn, s: Scoped = Depends(scoped)):
    if body.status not in ("OPEN", "CLOSED", "SUPPRESSED"):
        raise HTTPException(400, "상태가 올바르지 않습니다")
    s.conn.execute("SELECT gov.set_risk_status(%s, %s)", (event_id, body.status))
    return {"event_id": event_id, "status": body.status}


# ── 파이프라인 ──────────────────────────────────────────────────────────────

class PipelineIn(BaseModel):
    enabled: bool = True
    owner_user_id: str | None = Field(default=None, max_length=50)
    schedule_cron: str | None = Field(default=None, max_length=50)


@router.put("/pipelines/{pipeline_id}")
def update_pipeline(pipeline_id: str, body: PipelineIn, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.update_pipeline(%s, %s, %s, %s)", (pipeline_id, body.enabled, body.owner_user_id, body.schedule_cron))
    return {"pipeline_id": pipeline_id, "enabled": body.enabled}
