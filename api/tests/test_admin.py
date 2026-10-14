from .conftest import as_user

ADMIN = as_user("u-choi")


def test_admin_requires_admin_role(client):
    assert client.get("/api/admin/overview", headers=as_user("u-jung")).status_code == 403


def test_overview(client):
    d = client.get("/api/admin/overview", headers=ADMIN).json()
    assert [z["zone_id"] for z in d["zones"]] == ["RAW", "STANDARD", "SEMANTIC", "CURATED"]
    assert {p["pipeline_id"]: p["last_status"] for p in d["pipelines"]}["p-kg-materialize"] == "PARTIAL"
    assert d["counts"]["classes"] > 100


def test_catalog_and_dataset_detail(client):
    raw = client.get("/api/admin/datasets", params={"zone": "RAW"}, headers=ADMIN).json()
    # 데이터 넣기 테스트가 원천 데이터셋을 더 만들 수 있다
    assert {"raw.eap07.trace", "raw.mes.lot_history"} <= {d["dataset_id"] for d in raw} and {d["zone_id"] for d in raw} == {"RAW"}
    d = client.get("/api/admin/datasets/raw.mes.lot_history", headers=ADMIN).json()
    assert d["downstream"][0]["dataset_id"] == "std.lot"
    assert d["mappings"][0]["status"] == "APPROVED"
    assert d["quality_runs"][0]["violation_count"] == 20


def test_ontology(client):
    assert any(c["local_name"] == "Lot" for c in client.get("/api/admin/ontology/classes", params={"q": "로트"}, headers=ADMIN).json())
    d = client.get("/api/admin/ontology/classes/Lot", headers=ADMIN).json()
    assert d["links"] and any(a["label_ko"] == "로트 보류" for a in d["actions"])


def test_lineage_and_quality(client):
    assert len(client.get("/api/admin/lineage", headers=ADMIN).json()["edges"]) >= 6
    q = client.get("/api/admin/quality", headers=ADMIN).json()
    assert q["rules"][0]["rule_id"] == "ksx-lot-structure" and len(q["violations"]) == 2


def test_access_lists_assignments_for_admin_only(client):
    d = client.get("/api/admin/access", headers=ADMIN).json()
    assert {"u-kim", "u-choi"} <= {a["user_id"] for a in d["assignments"]}
    # 빈 DB 에서도 감사 기록이 하나는 있도록 로트를 먼저 조회한다
    assert client.get("/api/lots/LOT-2026-0731", headers=ADMIN).status_code == 200
    assert any(a["object_ref"] == "ksx.lot:LOT-2026-0731" for a in client.get("/api/admin/audit", headers=ADMIN).json())


def test_access_request_decision(client):
    # 신청자 본인은 데이터 관리 역할이 없어 화면 자체가 막히고, 관리자는 승인할 수 있다 (재실행 시엔 이미 처리됨 409)
    r = client.post("/api/admin/access/00000000-0000-4000-8000-00000000c001/decision", headers=ADMIN, json={"approve": True})
    assert r.status_code in (200, 409)
    if r.status_code == 200:
        assert r.json()["status"] == "APPROVED"
