import pytest

from .conftest import as_user

def test_health(client):
    assert client.get("/api/health").json() == {"ok": True}


def test_me_scope(client):
    jung = client.get("/api/me", headers=as_user("u-jung")).json()
    assert (jung["enterprise_id"], jung["site_ids"], jung["plant_ids"]) == ("ACME", "HQ", "P1")
    kim = client.get("/api/me", headers=as_user("u-kim")).json()
    assert kim["roles"] == ["quality_engineer"] and kim["plant_ids"] == "*"


def test_unknown_user(client):
    assert client.get("/api/me", headers=as_user("nobody")).status_code == 401


def test_home(client, fresh_hold):
    h = client.get("/api/home", headers=as_user("u-jung")).json()
    assert any(r["risk_level"] == "CRITICAL" for r in h["risks"])
    assert h["pending_approvals"] >= 1
    assert {s["lot_id"] for s in h["spec_outs"]} == {"LOT-2026-0731"}
    assert h["kpi"]["wip_lots"] >= 1


def test_lot_page(client):
    r = client.get("/api/lots/LOT-2026-0731", headers=as_user("u-jung"))
    assert r.status_code == 200
    d = r.json()
    assert d["lot"]["item_name"] == "BGA 패키지 A100"
    assert [a["lot_id"] for a in d["ancestors"]] == ["LOT-2026-0730"]
    assert len(d["spec_outs"]) == 2
    assert d["orders"][0]["sales_order_id"] == "SD-5001"
    assert d["risks"] and d["actions"]
    assert sum(x["qty"] for x in d["defects"]) == 34


def test_out_of_scope_user_sees_nothing(client):
    h = as_user("u-park")  # HQ/P2 만 볼 수 있다
    assert client.get("/api/lots/LOT-2026-0731", headers=h).status_code == 404
    assert client.get("/api/search", params={"q": "LOT"}, headers=h).json()["results"] == []
    assert client.get("/api/home", headers=h).json()["risks"] == []
    r = client.post("/api/agent/query", headers=h, json={"sql": "select count(*) as n from ksx.lot"})
    assert r.json()["rows"] == [{"n": 0}]


def test_lot_not_found(client):
    assert client.get("/api/lots/NOPE", headers=as_user("u-jung")).status_code == 404


def test_equipment(client):
    d = client.get("/api/equipment/EQ-07", headers=as_user("u-jung")).json()
    assert d["parameters"][0]["usl"] == 255
    assert len(d["trace"]) == 3


def test_kpis(client):
    h = as_user("u-lee")
    assert client.get("/api/kpi/yield", headers=h).json()
    assert client.get("/api/kpi/ppm", headers=h).json()
    otd = client.get("/api/kpi/otd", headers=h).json()
    assert otd["otd_pct"] == 100.0
    assert client.get("/api/kpi/wip", headers=h).json()
    assert client.get("/api/kpi/risks", headers=h).json()[0]["lot_id"] == "LOT-2026-0731"


def test_search(client):
    res = client.get("/api/search", params={"q": "리플로우"}, headers=as_user("u-jung")).json()["results"]
    assert ("equipment", "EQ-07") in {(r["kind"], r["id"]) for r in res}


def test_catalog(client):
    ids = {d["dataset_id"] for d in client.get("/api/catalog/datasets", headers=as_user("u-jung")).json()}
    assert "raw.eap07.trace" in ids


def test_inbox_can_decide_hint(client, fresh_hold):
    jung = {r["execution_id"]: r for r in client.get("/api/inbox", headers=as_user("u-jung")).json()}
    kim = {r["execution_id"]: r for r in client.get("/api/inbox", headers=as_user("u-kim")).json()}
    assert jung[fresh_hold]["can_decide"] is False
    assert kim[fresh_hold]["can_decide"] is True


def test_agent_query_scoped(client):
    r = client.post("/api/agent/query", headers=as_user("u-jung"),
                    json={"sql": "select lot_id from ksx.lot where lot_id like 'LOT-2026-%' order by lot_id"})
    assert r.status_code == 200, r.text
    assert r.json()["row_count"] == 4


@pytest.mark.parametrize("bad", [
    "select 1; select 2",
    "select set_config('app.enterprise_id', '*', true)",
    "select * from gov.app_user",
    "delete from ksx.lot",
])
def test_agent_query_rejects(client, bad):
    r = client.post("/api/agent/query", headers=as_user("u-jung"), json={"sql": bad})
    assert r.status_code in (400, 403), r.text


# 승인은 상태를 바꾸므로 마지막에. 권한 없는 사람은 거절, 승인자는 통과, 두 번째는 거절.
def test_decision_flow(client, fresh_hold):
    url = f"/api/inbox/{fresh_hold}/decision"
    r = client.post(url, headers=as_user("u-jung"), json={"approve": True})
    assert r.status_code == 409 and "역할" in r.json()["detail"]
    r = client.post(url, headers=as_user("u-kim"), json={"approve": True, "note": "EQ-07 점검 후 재개"})
    assert r.status_code == 200 and r.json()["status"] == "APPROVED"
    r = client.post(url, headers=as_user("u-kim"), json={"approve": False})
    assert r.status_code == 409
