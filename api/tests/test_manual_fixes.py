"""매뉴얼을 쓰며 찾은 문제들 (V0013): 한글 파일 이름 데이터셋 ID, 되돌리기 복원, 품질 목록, 원천 데이터셋 지우기, 질의 작업대 오류."""
import uuid

from .conftest import as_user

ADMIN = as_user("u-choi")


def _source(client) -> str:
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    r = client.post("/api/admin/sources", headers=ADMIN,
                    json={"source_system_id": sid, "label": "매뉴얼 테스트", "system_type": "MES", "db_kind": "FILE"})
    assert r.status_code == 200, r.text
    return sid


def _upload(client, sid: str, name: str, body: bytes, entity: str | None = None) -> dict:
    data = {"source_system_id": sid} | ({"entity": entity} if entity else {})
    r = client.post("/api/admin/upload", headers=ADMIN, data=data, files={"file": (name, body, "text/csv")})
    assert r.status_code == 200, r.text
    return client.get(f"/api/admin/batches/{r.json()['batch_id']}", headers=ADMIN).json()


def _lot_batch(client, sid: str, lot: str, qty: int) -> str:
    d = _upload(client, sid, "lots.csv", f"로트식별자,로트명,PLANT_ID,lot_created_quantity\n{lot},테스트,P1,{qty}\n".encode(), "lot_master")
    r = client.post(f"/api/admin/batches/{d['batch']['batch_id']}/standardize", headers=ADMIN,
                    json={"table": "lot", "column_map": d["suggested_map"], "site_id": "HQ", "keep_extras": False, "auto_quality": False})
    assert r.status_code == 200 and r.json()["rows_out"] == 1, r.text
    return d["batch"]["batch_id"]


def _qty(client, lot: str):
    r = client.post("/api/agent/query", headers=ADMIN, json={"sql": f"SELECT lot_created_quantity AS q FROM ksx.lot WHERE lot_id = '{lot}'"})
    assert r.status_code == 200, r.text
    rows = r.json()["rows"]
    return float(rows[0]["q"]) if rows else None


def test_korean_file_names_get_separate_datasets(client):
    sid = _source(client)
    a = _upload(client, sid, "발주_예시.csv", "a,b\n1,2\n".encode())["batch"]["dataset_id"]
    b = _upload(client, sid, "실적_예시.csv", "a,b\n1,2\n".encode())["batch"]["dataset_id"]
    again = _upload(client, sid, "발주_예시.csv", "a,b\n3,4\n".encode())["batch"]["dataset_id"]
    assert a != b and a == again
    assert a.startswith(f"raw.{sid.lower()}.h") and "___" not in a
    # 영문 이름은 예전 그대로
    assert _upload(client, sid, "x.csv", b"a\n1\n", "purchase_order")["batch"]["dataset_id"] == f"raw.{sid.lower()}.purchase_order"


def test_rollback_restores_overwritten_rows(client):
    sid = _source(client)
    lot = "LOT-RB" + uuid.uuid4().hex[:6].upper()
    a = _lot_batch(client, sid, lot, 10)
    b = _lot_batch(client, sid, lot, 20)
    assert _qty(client, lot) == 20
    r = client.post(f"/api/admin/batches/{b}/rollback", headers=ADMIN)
    assert r.status_code == 200, r.text
    assert r.json()["rows"] == 1 and r.json()["restored_rows"] == 1
    assert _qty(client, lot) == 10                       # 덮어쓰기 전 값으로 돌아왔다
    assert client.post(f"/api/admin/batches/{a}/rollback", headers=ADMIN).json()["restored_rows"] == 0
    assert _qty(client, lot) is None                     # 처음 넣은 배치까지 되돌리면 없어진다

    # 앞 배치를 먼저 되돌린 뒤 뒤 배치를 되돌리면, 이미 되돌린 배치의 값은 되살리지 않는다
    lot2 = lot + "X"
    a2 = _lot_batch(client, sid, lot2, 1)
    b2 = _lot_batch(client, sid, lot2, 2)
    assert client.post(f"/api/admin/batches/{a2}/rollback", headers=ADMIN).json()["rows"] == 0   # 뒤 배치가 덮어써 남는다
    assert _qty(client, lot2) == 2
    assert client.post(f"/api/admin/batches/{b2}/rollback", headers=ADMIN).json()["restored_rows"] == 0
    assert _qty(client, lot2) is None


def test_quality_list_shows_clean_runs(client):
    rid = "t-clean-" + uuid.uuid4().hex[:6]
    body = {"label_ko": "위반 없는 규칙", "dimension": "유효성", "target_dataset_id": "std.lot", "severity": "Warning", "threshold": 90, "enabled": True,
            "sql_check": "SELECT lot_id AS focus_node, 'lot_id' AS result_path, 'x' AS message FROM ksx.lot WHERE false"}
    assert client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json=body).status_code == 200
    assert client.post(f"/api/admin/quality/rules/{rid}/run", headers=ADMIN).json()["violation_count"] == 0
    rule = next(x for x in client.get("/api/admin/quality", headers=ADMIN).json()["rules"] if x["rule_id"] == rid)
    assert rule["last_run_at"] is not None and rule["violation_count"] == 0 and rule["conformance_rate"] == 100
    # 실행 기록만 있고 위반이 없는 규칙은 지울 수 있다
    assert client.delete(f"/api/admin/quality/rules/{rid}", headers=ADMIN).status_code == 200


def test_delete_raw_dataset_after_standardize(client):
    sid = _source(client)
    lot = "LOT-DD" + uuid.uuid4().hex[:6].upper()
    b = _lot_batch(client, sid, lot, 5)
    ds = client.get(f"/api/admin/batches/{b}", headers=ADMIN).json()["batch"]["dataset_id"]
    assert client.get(f"/api/admin/datasets/{ds}", headers=ADMIN).json()["downstream"]
    assert client.delete(f"/api/admin/datasets/{ds}", headers=ADMIN).status_code == 409   # 배치가 남아 있다
    assert client.delete(f"/api/admin/batches/{b}", headers=ADMIN).status_code == 200
    r = client.delete(f"/api/admin/datasets/{ds}", headers=ADMIN)
    assert r.status_code == 200, r.text
    assert client.get(f"/api/admin/datasets/{ds}", headers=ADMIN).status_code == 404
    assert _qty(client, lot) == 5                        # 표준 존 행은 남는다


def test_workbench_errors_are_readable(client):
    r = client.post("/api/agent/query", headers=ADMIN, json={"sql": "DELETE FROM ksx.lot"})
    assert r.status_code in (400, 403)
    assert "조회(SELECT)만" in r.json()["detail"] and r.json()["raw"]
    r = client.post("/api/agent/query", headers=ADMIN, json={"sql": "SELECT no_such_col FROM ksx.lot"})
    assert r.status_code == 400
    assert r.json()["detail"].startswith("열이 없습니다 (no_such_col)") and "does not exist" in r.json()["raw"]
    r = client.post("/api/agent/query", headers=ADMIN, json={"sql": "SELECT * FROM lot"})
    assert r.json()["detail"].startswith("표가 없습니다 (lot)")
    r = client.post("/api/agent/query", headers=ADMIN, json={"sql": "SELEC 1"})
    assert r.json()["detail"].startswith("SQL 문법이 맞지 않습니다")
