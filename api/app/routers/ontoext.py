"""온톨로지 확장 CRUD 3차 — 회사 확장 클래스·속성·관계, 확장 제안 결정, 온톨로지 버전 발행, 표준 존 배치 되돌리기, 확장 속성 조회.

표준(ksx)은 읽기 전용. 쓰기는 모두 gov.* SECURITY DEFINER 함수로만 하고, 함수가 역할을 다시 확인하며 감사 기록을 남긴다.
"""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from ..deps import Scoped
from .admin import admin_scoped

router = APIRouter(prefix="/api/admin", tags=["ontology-extension"])

ARCON = "https://ontology.impix.co.kr/arcon/"
XSD = "http://www.w3.org/2001/XMLSchema#"
XSD_TYPES = ("string", "decimal", "integer", "date", "dateTime", "boolean")


@router.get("/ontology/extensions")
def extensions(s: Scoped = Depends(admin_scoped)):
    c = s.conn
    classes = c.execute(
        "SELECT c.class_iri, c.local_name, c.label_ko, c.label_en, c.business_group, c.parent_class_iri, p.label_ko AS parent_label,"
        "       c.is_event, c.definition_ko, c.version_id,"
        "       (SELECT count(*) FROM onto.property x WHERE x.domain_class_iri = c.class_iri) AS properties,"
        "       (SELECT count(*) FROM catalog.dataset d WHERE d.represents_class_iri = c.class_iri) AS datasets"
        "  FROM onto.class c LEFT JOIN onto.class p ON p.class_iri = c.parent_class_iri"
        " WHERE NOT c.is_standard ORDER BY c.business_group NULLS LAST, c.label_ko").fetchall()
    props = c.execute(
        "SELECT p.property_iri, p.local_name, p.kind, p.label_ko, p.range_iri, r.label_ko AS range_label, p.domain_class_iri, d.label_ko AS domain_label,"
        "       p.unit, p.code_scheme, p.definition_ko, p.version_id,"
        "       (SELECT count(*) FROM ksx.extension_attribute e WHERE e.property_iri = p.property_iri) AS values_stored"
        "  FROM onto.property p LEFT JOIN onto.class d ON d.class_iri = p.domain_class_iri LEFT JOIN onto.class r ON r.class_iri = p.range_iri"
        " WHERE p.property_iri LIKE %s ORDER BY d.label_ko NULLS LAST, p.local_name", (ARCON + "%",)).fetchall()
    links = c.execute(
        "SELECT l.link_id, l.subject_class_iri, sc.label_ko AS subject_label, l.property_iri, p.local_name AS property_name, p.label_ko AS property_label,"
        "       l.object_class_iri, oc.label_ko AS object_label, l.relation_kind"
        "  FROM onto.link l JOIN onto.class sc ON sc.class_iri = l.subject_class_iri JOIN onto.class oc ON oc.class_iri = l.object_class_iri"
        "  JOIN onto.property p ON p.property_iri = l.property_iri WHERE NOT l.is_standard ORDER BY sc.label_ko, p.local_name").fetchall()
    versions = c.execute("SELECT v.version_id, v.ontology_iri, v.version_info, v.source, v.status, v.released_at,"
                         "       (SELECT count(*) FROM onto.class x WHERE x.version_id = v.version_id) AS classes,"
                         "       (SELECT count(*) FROM onto.property x WHERE x.version_id = v.version_id) AS properties"
                         "  FROM onto.ontology_version v ORDER BY v.released_at DESC NULLS LAST, v.version_id DESC").fetchall()
    pending = c.execute("SELECT count(*) AS n FROM onto.class WHERE NOT is_standard AND version_id IS NULL").fetchone()["n"] + \
        c.execute("SELECT count(*) AS n FROM onto.property WHERE property_iri LIKE %s AND version_id IS NULL", (ARCON + "%",)).fetchone()["n"]
    return {"classes": classes, "properties": props, "links": links, "versions": versions, "unpublished": pending}


# ── 확장 클래스 ─────────────────────────────────────────────────────────────

class ExtClassIn(BaseModel):
    label_ko: str = Field(min_length=1, max_length=200)
    label_en: str | None = Field(default=None, max_length=200)
    business_group: str | None = Field(default=None, max_length=50)
    parent_class_iri: str | None = Field(default=None, max_length=300)
    definition_ko: str | None = Field(default=None, max_length=2000)
    is_event: bool = False


@router.put("/ontology/ext/classes/{local_name}")
def save_ext_class(local_name: str, body: ExtClassIn, s: Scoped = Depends(admin_scoped)):
    iri = s.conn.execute("SELECT gov.save_ext_class(%s, %s, %s, %s, %s, %s, %s) AS iri",
                         (local_name, body.label_ko, body.label_en, body.business_group, body.parent_class_iri, body.definition_ko, body.is_event)).fetchone()["iri"]
    return {"class_iri": iri, "local_name": local_name}


@router.delete("/ontology/ext/classes/{local_name}")
def delete_ext_class(local_name: str, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.delete_ext_class(%s)", (ARCON + local_name,))
    return {"class_iri": ARCON + local_name, "deleted": True}


# ── 확장 속성 ───────────────────────────────────────────────────────────────

class ExtPropertyIn(BaseModel):
    kind: str = "DATATYPE"
    label_ko: str = Field(min_length=1, max_length=200)
    domain_class_iri: str = Field(max_length=300)
    range_iri: str | None = Field(default=None, max_length=300)   # DATATYPE: xsd:… (또는 'decimal' 같은 짧은 이름), OBJECT: 클래스 IRI
    unit: str | None = Field(default=None, max_length=30)
    code_scheme: str | None = Field(default=None, max_length=200)
    definition_ko: str | None = Field(default=None, max_length=2000)


def _range(kind: str, r: str | None) -> str | None:
    if kind == "DATATYPE" and r and not r.startswith("http"):
        if r not in XSD_TYPES:
            raise HTTPException(400, "값 형은 string·decimal·integer·date·dateTime·boolean 중 하나입니다")
        return XSD + r
    return r


@router.put("/ontology/ext/properties/{local_name}")
def save_ext_property(local_name: str, body: ExtPropertyIn, s: Scoped = Depends(admin_scoped)):
    if body.kind not in ("DATATYPE", "OBJECT", "CODE"):
        raise HTTPException(400, "속성 종류가 올바르지 않습니다")
    iri = s.conn.execute("SELECT gov.save_ext_property(%s, %s, %s, %s, %s, %s, %s, %s) AS iri",
                         (local_name, body.kind, body.label_ko, body.domain_class_iri, _range(body.kind, body.range_iri), body.unit,
                          body.code_scheme, body.definition_ko)).fetchone()["iri"]
    return {"property_iri": iri, "local_name": local_name}


@router.delete("/ontology/ext/properties/{local_name}")
def delete_ext_property(local_name: str, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.delete_ext_property(%s)", (ARCON + local_name,))
    return {"property_iri": ARCON + local_name, "deleted": True}


# ── 확장 관계 ───────────────────────────────────────────────────────────────

class ExtLinkIn(BaseModel):
    subject_class_iri: str = Field(max_length=300)
    property_iri: str = Field(max_length=300)
    object_class_iri: str = Field(max_length=300)
    relation_kind: str | None = Field(default=None, max_length=30)


@router.post("/ontology/ext/links")
def save_ext_link(body: ExtLinkIn, s: Scoped = Depends(admin_scoped)):
    lid = s.conn.execute("SELECT gov.save_ext_link(%s, %s, %s, %s) AS id",
                         (body.subject_class_iri, body.property_iri, body.object_class_iri, body.relation_kind)).fetchone()["id"]
    return {"link_id": lid}


@router.delete("/ontology/ext/links/{link_id}")
def delete_ext_link(link_id: int, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.delete_ext_link(%s)", (link_id,))
    return {"link_id": link_id, "deleted": True}


# ── 버전 발행 ───────────────────────────────────────────────────────────────

class PublishIn(BaseModel):
    version_info: str = Field(min_length=1, max_length=60)
    note: str | None = Field(default=None, max_length=500)


@router.post("/ontology/versions/publish")
def publish_version(body: PublishIn, s: Scoped = Depends(admin_scoped)):
    return s.conn.execute("SELECT gov.publish_ontology_version(%s, %s) AS r", (body.version_info, body.note)).fetchone()["r"]


@router.delete("/ontology/versions/{version_id}")
def delete_version(version_id: str, s: Scoped = Depends(admin_scoped)):
    s.conn.execute("SELECT gov.delete_ontology_version(%s)", (version_id,))
    return {"version_id": version_id, "deleted": True}


# ── 확장 제안 ───────────────────────────────────────────────────────────────

@router.get("/ontology/proposals")
def proposals(status: str | None = Query(default="PROPOSED"), s: Scoped = Depends(admin_scoped)):
    return s.conn.execute(
        "SELECT p.*, c.label_ko AS target_label, d.title_ko AS dataset_title, m.local_name AS matched_name"
        "  FROM onto.extension_proposal p LEFT JOIN onto.class c ON c.class_iri = p.target_class_iri"
        "  LEFT JOIN catalog.dataset d ON d.dataset_id = p.dataset_id LEFT JOIN onto.property m ON m.property_iri = p.matched_property_iri"
        " WHERE %(st)s::text IS NULL OR %(st)s = 'ALL' OR p.status = %(st)s"
        " ORDER BY CASE p.status WHEN 'PROPOSED' THEN 0 ELSE 1 END, p.created_at DESC LIMIT 300", {"st": status}).fetchall()


class DecideIn(BaseModel):
    accept: bool
    local_name: str | None = Field(default=None, max_length=100)
    label_ko: str | None = Field(default=None, max_length=200)
    target_class_iri: str | None = Field(default=None, max_length=300)
    range_iri: str | None = Field(default=None, max_length=300)
    unit: str | None = Field(default=None, max_length=30)
    kind: str | None = None


@router.post("/ontology/proposals/{proposal_id}/decide")
def decide_proposal(proposal_id: int, body: DecideIn, s: Scoped = Depends(admin_scoped)):
    if body.kind not in (None, "PROPERTY", "CLASS", "REF"):
        raise HTTPException(400, "종류가 올바르지 않습니다")
    rng = _range("DATATYPE", body.range_iri) if body.kind in (None, "PROPERTY") else body.range_iri
    return s.conn.execute("SELECT gov.decide_extension_proposal(%s, %s, %s, %s, %s, %s, %s, %s) AS r",
                          (proposal_id, body.accept, body.local_name, body.label_ko, body.target_class_iri, rng, body.unit, body.kind)).fetchone()["r"]


# ── 확장 속성 값 조회 (표준 데이터셋 상세에서) ─────────────────────────────

@router.get("/extension-attributes")
def extension_attributes(table: str = Query(max_length=63), limit: int = Query(default=50, ge=1, le=500), s: Scoped = Depends(admin_scoped)):
    summary = s.conn.execute(
        "SELECT e.attr_name, e.property_iri, p.local_name AS property_name, p.label_ko AS property_label, count(*) AS rows, max(e.lake_loaded_at) AS last_loaded_at"
        "  FROM ksx.extension_attribute e LEFT JOIN onto.property p ON p.property_iri = e.property_iri"
        " WHERE e.table_name = %s GROUP BY e.attr_name, e.property_iri, p.local_name, p.label_ko ORDER BY e.attr_name", (table,)).fetchall()
    rows = s.conn.execute(
        "SELECT record_key, attr_name, attr_value, lake_batch_id, lake_loaded_at FROM ksx.extension_attribute"
        " WHERE table_name = %s ORDER BY lake_loaded_at DESC, record_key LIMIT %s", (table, limit)).fetchall()
    return {"summary": summary, "rows": rows}


# ── 표준 존 배치 되돌리기 ───────────────────────────────────────────────────

@router.post("/batches/{batch_id}/rollback")
def rollback_batch(batch_id: UUID, s: Scoped = Depends(admin_scoped)):
    return s.conn.execute("SELECT gov.rollback_batch(%s) AS r", (batch_id,)).fetchone()["r"]
