import uuid

from .conftest import as_user

ADMIN = as_user("u-choi")        # admin + data_steward
QE = as_user("u-kim")            # quality_engineer
PM = as_user("u-lee")            # production_manager (HQ/P1)
ANALYST = as_user("u-jung")


def _raw_dataset(client, rows=b"a,b\n1,2\n3,4\n"):
    """원천 존 데이터셋 하나를 새로 만든다 (원천 등록 + 파일 올리기)."""
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    client.post("/api/admin/sources", headers=ADMIN, json={"source_system_id": sid, "label": "스튜어드 테스트", "system_type": "MES", "db_kind": "FILE"})
    up = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": sid}, files={"file": ("x.csv", rows, "text/csv")}).json()
    return up["batch_id"], client.get(f"/api/admin/batches/{up['batch_id']}", headers=ADMIN).json()["batch"]["dataset_id"]


def test_dataset_meta_update_and_delete(client):
    assert client.put("/api/admin/datasets/std.lot", headers=ANALYST, json={"title_ko": "x"}).status_code == 403
    before = client.get("/api/admin/datasets/std.lot", headers=ADMIN).json()["dataset"]
    body = {"title_ko": "로트 (테스트)", "description": "스튜어드가 고친 설명", "sensitivity": "CONFIDENTIAL", "pseudonymized": True,
            "retention": "5 years", "owner_user_id": "u-kim", "steward_user_id": "u-choi", "tags": ["mes", " lot "]}
    r = client.put("/api/admin/datasets/std.lot", headers=ADMIN, json=body)
    assert r.status_code == 200, r.text
    d = client.get("/api/admin/datasets/std.lot", headers=ADMIN).json()["dataset"]
    assert d["title_ko"] == "로트 (테스트)" and d["sensitivity"] == "CONFIDENTIAL" and d["owner_user_id"] == "u-kim" and d["tags"] == ["mes", "lot"]
    assert client.put("/api/admin/datasets/std.lot", headers=ADMIN, json=body | {"owner_user_id": "nobody"}).status_code == 409
    assert client.put("/api/admin/datasets/std.lot", headers=ADMIN, json=body | {"sensitivity": "TOP"}).status_code == 400
    assert client.put("/api/admin/datasets/nope", headers=ADMIN, json=body).status_code == 409
    # 되돌리기
    restore = {k: before[k] for k in ("title_ko", "description", "sensitivity", "pseudonymized", "retention", "owner_user_id", "steward_user_id", "tags")}
    assert client.put("/api/admin/datasets/std.lot", headers=ADMIN, json=restore).status_code == 200
    # 감사 기록
    assert any(a["action"] == "update_dataset" and a["dataset_id"] == "std.lot" for a in client.get("/api/admin/audit?action=update_dataset", headers=ADMIN).json())

    # 지우기: 표준 존은 안 되고, 원천 존은 배치를 먼저 지워야 한다
    assert client.delete("/api/admin/datasets/std.lot", headers=ADMIN).status_code == 409
    batch_id, ds = _raw_dataset(client)
    assert client.delete(f"/api/admin/datasets/{ds}", headers=ADMIN).status_code == 409
    client.delete(f"/api/admin/batches/{batch_id}", headers=ADMIN)
    assert client.delete(f"/api/admin/datasets/{ds}", headers=ADMIN).status_code == 200
    assert client.get(f"/api/admin/datasets/{ds}", headers=ADMIN).status_code == 404
    assert client.delete(f"/api/admin/datasets/{ds}", headers=ADMIN).status_code == 409


def test_field_update_and_mapping_decision(client):
    url = "/api/admin/datasets/std.lot/fields/lot_created_quantity"
    f0 = next(f for f in client.get("/api/admin/datasets/std.lot", headers=ADMIN).json()["fields"] if f["field_name"] == "lot_created_quantity")
    r = client.put(url, headers=ADMIN, json={"label_ko": "로트 수량(테스트)", "description": "검사 수량 포함", "is_pii": False,
                                             "maps_to_property_iri": f0["maps_to_property_iri"], "decision": "ACCEPT"})
    assert r.status_code == 200, r.text
    f = r.json()
    assert f["label_ko"] == "로트 수량(테스트)" and f["description"] == "검사 수량 포함" and f["mapping_status"] == "APPROVED" and f["mapping_method"] == "human"
    # 반려하면 속성이 떨어진다
    f = client.put(url, headers=ADMIN, json={"label_ko": f0["label_ko"], "maps_to_property_iri": f0["maps_to_property_iri"], "decision": "REJECT"}).json()
    assert f["maps_to_property_iri"] is None and f["mapping_status"] == "REJECTED"
    assert client.put(url, headers=ADMIN, json={"maps_to_property_iri": "https://nope/x"}).status_code == 409
    assert client.put(url, headers=ADMIN, json={"decision": "MAYBE"}).status_code == 400
    assert client.put("/api/admin/datasets/std.lot/fields/no_such_col", headers=ADMIN, json={}).status_code == 409
    # 되돌리기
    f = client.put(url, headers=ADMIN, json={"label_ko": f0["label_ko"], "description": f0["description"], "is_pii": f0["is_pii"],
                                             "maps_to_property_iri": f0["maps_to_property_iri"], "decision": "ACCEPT"}).json()
    assert f["maps_to_property_iri"] == f0["maps_to_property_iri"]
    assert client.get("/api/admin/ontology/properties", headers=ADMIN).json()[0]["property_iri"]

    # 매핑 버전 상태
    mid = "ksx9101/trace.rml.ttl@v1"
    assert client.post("/api/admin/mappings/status", headers=ADMIN, json={"mapping_id": mid, "status": "APPROVED"}).json()["status"] == "APPROVED"
    assert client.post("/api/admin/mappings/status", headers=ADMIN, json={"mapping_id": mid, "status": "APPROVED"}).status_code == 409
    m = next(m for m in client.get("/api/admin/datasets/raw.eap07.trace", headers=ADMIN).json()["mappings"] if m["mapping_id"] == mid)
    assert m["status"] == "APPROVED" and m["approved_by"] == "u-choi"
    assert client.post("/api/admin/mappings/status", headers=ADMIN, json={"mapping_id": mid, "status": "REVIEW"}).status_code == 200
    assert client.post("/api/admin/mappings/status", headers=ADMIN, json={"mapping_id": "nope", "status": "REVIEW"}).status_code == 409


def test_quality_rule_crud_run_and_violation(client):
    rid = "t-rule-" + uuid.uuid4().hex[:6]
    _, ds = _raw_dataset(client)
    body = {"label_ko": "테스트 규칙", "dimension": "완전성", "target_dataset_id": ds, "severity": "Warning", "threshold": 90, "enabled": True,
            "sql_check": "SELECT lot_id AS focus_node, 'lot_quantity' AS result_path, '수량 확인' AS message FROM ksx.lot ORDER BY lot_id LIMIT 1"}
    assert client.put(f"/api/admin/quality/rules/{rid}", headers=ANALYST, json=body).status_code == 403
    r = client.put(f"/api/admin/quality/rules/{rid}", headers=QE, json=body)   # 품질 엔지니어도 된다
    assert r.status_code == 200, r.text
    assert client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json=body | {"sql_check": "DELETE FROM ksx.lot"}).status_code == 409
    assert client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json=body | {"target_dataset_id": None}).status_code == 409
    assert client.put("/api/admin/quality/rules/bad id", headers=ADMIN, json=body).status_code == 409
    rules = {x["rule_id"]: x for x in client.get("/api/admin/quality", headers=ADMIN).json()["rules"]}
    assert rules[rid]["threshold"] == 90 and rules[rid]["target_dataset_id"] == ds and rules[rid]["last_run_at"] is None

    # 바로 실행: 검사식이 돌려준 행이 위반이 되고, 데이터셋 적합률이 갱신된다
    r = client.post(f"/api/admin/quality/rules/{rid}/run", headers=ADMIN)
    assert r.status_code == 200, r.text
    out = r.json()
    assert out["violation_count"] == 1 and out["focus_count"] == 2 and out["conformance_rate"] == 50 and out["dataset_id"] == ds
    d = client.get(f"/api/admin/datasets/{ds}", headers=ADMIN).json()
    assert d["dataset"]["quality_status"] == "FAIL" and d["dataset"]["quality_score"] == 50 and d["quality_runs"][0]["violation_count"] == 1
    q = client.get("/api/admin/quality", headers=ADMIN).json()
    assert q["rules"] and next(x for x in q["rules"] if x["rule_id"] == rid)["conformance_rate"] == 50
    v = next(x for x in q["violations"] if x["rule_id"] == rid)
    assert v["result_path"] == "lot_quantity" and v["message"] == "수량 확인" and v["status"] == "OPEN"
    # 검사식 오류는 400
    client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json=body | {"sql_check": "SELECT * FROM no_such_table"})
    assert client.post(f"/api/admin/quality/rules/{rid}/run", headers=ADMIN).status_code == 400
    assert client.post("/api/admin/quality/rules/ksx-lot-structure/run", headers=ADMIN).status_code == 409   # SHACL 규칙엔 검사식이 없다

    # 위반 처리
    r = client.put(f"/api/admin/quality/violations/{v['violation_id']}", headers=ADMIN, json={"status": "ACK", "assignee_user_id": "u-kim"})
    assert r.status_code == 200, r.text
    v2 = next(x for x in client.get("/api/admin/quality", headers=ADMIN).json()["violations"] if x["violation_id"] == v["violation_id"])
    assert v2["status"] == "ACK" and v2["assignee_user_id"] == "u-kim"
    assert client.put(f"/api/admin/quality/violations/{v['violation_id']}", headers=ADMIN, json={"status": "FIXED", "assignee_user_id": "nobody"}).status_code == 409
    assert client.put("/api/admin/quality/violations/999999999", headers=ADMIN, json={"status": "FIXED"}).status_code == 409
    # 위반 기록이 있는 규칙은 못 지우고, 대신 끈다
    assert client.delete(f"/api/admin/quality/rules/{rid}", headers=ADMIN).status_code == 409
    assert client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json=body | {"enabled": False}).status_code == 200
    # 위반이 없는 새 규칙은 지워진다
    rid2 = rid + "b"
    client.put(f"/api/admin/quality/rules/{rid2}", headers=ADMIN, json=body)
    assert client.delete(f"/api/admin/quality/rules/{rid2}", headers=ADMIN).status_code == 200
    assert client.delete(f"/api/admin/quality/rules/{rid2}", headers=ADMIN).status_code == 409


def test_risk_status(client):
    eid = "00000000-0000-4000-8000-000000000731"
    assert client.post(f"/api/admin/risks/{eid}/status", headers=ANALYST, json={"status": "CLOSED"}).status_code == 409   # 역할 없음
    r = client.post(f"/api/admin/risks/{eid}/status", headers=PM, json={"status": "CLOSED"})   # 생산 관리자(HQ/P1)는 된다
    assert r.status_code == 200, r.text
    assert eid not in {x["event_id"] for x in client.get("/api/admin/overview", headers=ADMIN).json()["risks"]}
    assert client.post(f"/api/admin/risks/{eid}/status", headers=ADMIN, json={"status": "OPEN"}).status_code == 200
    assert eid in {x["event_id"] for x in client.get("/api/admin/overview", headers=ADMIN).json()["risks"]}
    assert client.post(f"/api/admin/risks/{uuid.uuid4()}/status", headers=ADMIN, json={"status": "CLOSED"}).status_code == 409
    assert client.post(f"/api/admin/risks/{eid}/status", headers=ADMIN, json={"status": "GONE"}).status_code == 400


def test_pipeline_update(client):
    assert client.put("/api/admin/pipelines/p-kpi", headers=QE, json={"enabled": False}).status_code == 409   # data_engineer 만
    r = client.put("/api/admin/pipelines/p-console-upload", headers=ADMIN, json={"enabled": False, "owner_user_id": "u-kim", "schedule_cron": "0 3 * * *"})
    assert r.status_code == 200, r.text
    p = next(x for x in client.get("/api/admin/overview", headers=ADMIN).json()["pipelines"] if x["pipeline_id"] == "p-console-upload")
    assert p["enabled"] is False and p["owner_user_id"] == "u-kim" and p["schedule_cron"] == "0 3 * * *"
    assert client.put("/api/admin/pipelines/p-kpi", headers=ADMIN, json={"enabled": True, "schedule_cron": "every day"}).status_code == 409
    assert client.put("/api/admin/pipelines/nope", headers=ADMIN, json={"enabled": True}).status_code == 409
    assert client.put("/api/admin/pipelines/p-console-upload", headers=ADMIN, json={"enabled": True, "owner_user_id": None, "schedule_cron": None}).status_code == 200
    assert client.get("/api/admin/people", headers=ADMIN).json()[0]["user_id"]
