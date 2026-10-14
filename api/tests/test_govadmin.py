import uuid
from datetime import date

from .conftest import as_user

ADMIN = as_user("u-choi")
STEWARD_ONLY = as_user("u-kim")   # quality_engineer: 관리 화면 밖
ANALYST = as_user("u-jung")


def test_admin_only_endpoints(client):
    assert client.get("/api/admin/users", headers=ANALYST).status_code == 403
    assert client.put("/api/admin/users/u-x", headers=STEWARD_ONLY, json={"display_name": "x"}).status_code == 403
    assert client.post("/api/admin/roles/grant", headers=ANALYST, json={"user_id": "u-jung", "role_id": "admin"}).status_code == 403


def test_user_and_role_crud(client):
    uid = "u-t" + uuid.uuid4().hex[:6]
    r = client.put(f"/api/admin/users/{uid}", headers=ADMIN, json={"display_name": "테스트 사용자", "email": "t@example.com"})
    assert r.status_code == 200, r.text
    users = {u["user_id"]: u for u in client.get("/api/admin/users", headers=ADMIN).json()}
    assert users[uid]["display_name"] == "테스트 사용자" and users[uid]["roles"] == []

    # 역할 주기: 범위 없는 analyst, 사업장·공장 범위의 production_manager
    assert client.post("/api/admin/roles/grant", headers=ADMIN, json={"user_id": uid, "role_id": "analyst"}).status_code == 200
    r = client.post("/api/admin/roles/grant", headers=ADMIN,
                    json={"user_id": uid, "role_id": "production_manager", "site_id": "HQ", "plant_id": "P1", "valid_until": "2030-12-31"})
    assert r.status_code == 200, r.text
    assert client.post("/api/admin/roles/grant", headers=ADMIN, json={"user_id": uid, "role_id": "analyst", "site_id": "NOPE"}).status_code == 409
    # 직접 입력한 사업장·공장: create_scope 면 마스터에 새로 등록하고 역할을 준다 (회사마다 사업장 목록이 다르다)
    tag = uid[-4:].upper()
    r = client.post("/api/admin/roles/grant", headers=ADMIN,
                    json={"user_id": uid, "role_id": "analyst", "site_id": f" S{tag} ", "plant_id": f"PL{tag}", "create_scope": True})
    assert r.status_code == 200, r.text
    assert (r.json()["site_created"], r.json()["plant_created"]) == (True, True)
    sc = client.get("/api/admin/scopes", headers=ADMIN).json()
    assert any(x["site_id"] == f"S{tag}" for x in sc["sites"]) and any(x["plant_id"] == f"PL{tag}" and x["site_id"] == f"S{tag}" for x in sc["plants"])
    r = client.post("/api/admin/roles/grant", headers=ADMIN, json={"user_id": uid, "role_id": "analyst", "site_id": f"S{tag}", "plant_id": f"PL{tag}", "create_scope": True})
    assert r.status_code == 200 and (r.json()["site_created"], r.json()["plant_created"]) == (False, False)
    assert client.post("/api/admin/roles/revoke", headers=ADMIN,
                       json={"user_id": uid, "role_id": "analyst", "site_id": f"S{tag}", "plant_id": f"PL{tag}"}).status_code == 200
    assert client.post("/api/admin/roles/grant", headers=ADMIN, json={"user_id": uid, "role_id": "nope"}).status_code == 409
    me = client.get("/api/me", headers=as_user(uid)).json()
    assert set(me["roles"]) == {"analyst", "production_manager"}
    # 새 사용자가 바로 API 를 쓸 수 있다
    assert client.get("/api/home", headers=as_user(uid)).status_code == 200

    # 역할 빼기
    assert client.post("/api/admin/roles/revoke", headers=ADMIN, json={"user_id": uid, "role_id": "analyst"}).status_code == 200
    assert client.post("/api/admin/roles/revoke", headers=ADMIN, json={"user_id": uid, "role_id": "analyst"}).status_code == 409
    assert client.get("/api/me", headers=as_user(uid)).json()["roles"] == ["production_manager"]
    # 내 admin 은 스스로 못 뺀다
    assert client.post("/api/admin/roles/revoke", headers=ADMIN, json={"user_id": "u-choi", "role_id": "admin"}).status_code == 409

    # 잠그면 로그인(resolve)이 안 된다
    assert client.put(f"/api/admin/users/{uid}", headers=ADMIN, json={"display_name": "테스트 사용자", "status": "LOCKED"}).status_code == 200
    assert client.get("/api/me", headers=as_user(uid)).status_code in (401, 403, 404)
    assert client.put("/api/admin/users/u-choi", headers=ADMIN, json={"display_name": "최관리", "status": "RETIRED"}).status_code == 409


def test_access_policy_crud(client):
    pid = "t-pol-" + uuid.uuid4().hex[:6]
    body = {"role_id": "analyst", "target_dataset_id": "std.lot", "max_sensitivity": "INTERNAL", "actions": ["read", "query"], "requires_approval": True}
    r = client.put(f"/api/admin/access-policies/{pid}", headers=ADMIN, json=body)
    assert r.status_code == 200, r.text
    rows = {p["policy_id"]: p for p in client.get("/api/admin/access-policies", headers=ADMIN).json()}
    assert rows[pid]["dataset_title"] and rows[pid]["actions"] == ["read", "query"] and rows[pid]["requires_approval"]
    assert client.put(f"/api/admin/access-policies/{pid}", headers=ADMIN, json=body | {"target_dataset_id": None}).status_code == 409
    assert client.put(f"/api/admin/access-policies/{pid}", headers=ADMIN, json=body | {"actions": ["drop"]}).status_code == 400
    assert client.delete(f"/api/admin/access-policies/{pid}", headers=ADMIN).status_code == 200
    assert client.delete(f"/api/admin/access-policies/{pid}", headers=ADMIN).status_code == 409


def test_action_policy_crud(client):
    pid = "t-act-" + uuid.uuid4().hex[:6]
    body = {"trigger_class_iri": "https://ontology.impix.co.kr/arcon/SpecOutEvent", "condition": {"risk_level": "HIGH"},
            "action_iri": "https://ontology.impix.co.kr/arcon/NotifyEngineer", "mode": "notify", "notify_role_ids": ["quality_engineer"],
            "suppress_minutes": 60, "enabled": False}
    r = client.put(f"/api/admin/action-policies/{pid}", headers=ADMIN, json=body)
    assert r.status_code == 200, r.text
    rows = {p["policy_id"]: p for p in client.get("/api/admin/action-policies", headers=ADMIN).json()}
    assert rows[pid]["suppress_minutes"] == 60 and rows[pid]["enabled"] is False and rows[pid]["action_label"] == "엔지니어 알림"
    assert client.put(f"/api/admin/action-policies/{pid}", headers=ADMIN, json=body | {"mode": "approval"}).status_code == 409  # 승인자 없음
    assert client.delete(f"/api/admin/action-policies/{pid}", headers=ADMIN).status_code == 200
    # 실행 기록이 있는 시드 정책은 못 지운다
    assert client.delete("/api/admin/action-policies/otd-risk", headers=ADMIN).status_code == 409
    assert "otd-risk" in rows
    assert client.get("/api/admin/ontology/actions", headers=ADMIN).json()[0]["label_ko"]


def test_access_request_create_and_cancel(client):
    body = {"dataset_id": "std.lot", "purpose": "수율 분석을 위해 로트 데이터가 필요합니다", "actions": ["read"],
            "period_from": str(date.today()), "period_to": "2030-01-01"}
    # 이미 대기 중인 요청이 있으면 치우고 시작
    for r in client.get("/api/access-requests", headers=ANALYST).json():
        if r["status"] == "REQUESTED":
            client.delete(f"/api/access-requests/{r['request_id']}", headers=ANALYST)
    r = client.post("/api/access-requests", headers=ANALYST, json=body)
    assert r.status_code == 200, r.text
    rid = r.json()["request_id"]
    assert client.post("/api/access-requests", headers=ANALYST, json=body).status_code == 409  # 중복
    assert client.post("/api/access-requests", headers=ANALYST, json=body | {"dataset_id": "nope"}).status_code == 409
    mine = {x["request_id"]: x for x in client.get("/api/access-requests", headers=ANALYST).json()}
    assert mine[rid]["status"] == "REQUESTED" and mine[rid]["dataset_title"]
    # 관리자 화면에도 보인다
    assert any(x["request_id"] == rid for x in client.get("/api/admin/access", headers=ADMIN).json()["requests"])
    # 남이 취소할 수 없다
    assert client.delete(f"/api/access-requests/{rid}", headers=ADMIN).status_code == 409
    assert client.delete(f"/api/access-requests/{rid}", headers=ANALYST).json()["status"] == "CANCELLED"
    assert client.delete(f"/api/access-requests/{rid}", headers=ANALYST).status_code == 409


def test_delete_batch(client):
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    client.post("/api/admin/sources", headers=ADMIN, json={"source_system_id": sid, "label": "지우기", "system_type": "MES", "db_kind": "FILE"})
    up = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": sid},
                     files={"file": ("x.csv", b"a,b\n1,2\n3,4\n", "text/csv")}).json()
    assert client.delete(f"/api/admin/batches/{up['batch_id']}", headers=ANALYST).status_code == 403
    r = client.delete(f"/api/admin/batches/{up['batch_id']}", headers=ADMIN)
    assert r.status_code == 200, r.text
    assert r.json()["records"] == 2 and r.json()["remaining_batches"] == 0
    assert client.get(f"/api/admin/batches/{up['batch_id']}", headers=ADMIN).status_code == 404
    assert client.delete(f"/api/admin/batches/{up['batch_id']}", headers=ADMIN).status_code == 409
