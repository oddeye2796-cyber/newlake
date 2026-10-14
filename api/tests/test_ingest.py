import io
import uuid

from openpyxl import Workbook

from .conftest import as_user

ADMIN = as_user("u-choi")


def _source(client) -> str:
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    r = client.post("/api/admin/sources", headers=ADMIN,
                    json={"source_system_id": sid, "label": "테스트 원천", "system_type": "MES", "db_kind": "FILE"})
    assert r.status_code == 200, r.text
    return sid


def test_ingest_requires_ingest_role(client):
    assert client.get("/api/admin/batches", headers=as_user("u-jung")).status_code == 403


def test_register_and_list_source(client):
    sid = _source(client)
    rows = {s["source_system_id"]: s for s in client.get("/api/admin/sources", headers=ADMIN).json()}
    assert rows[sid]["db_kind"] == "FILE" and rows[sid]["label_ko"] == "테스트 원천"
    assert "MES-A" in rows


def test_csv_upload_suggest_and_standardize(client):
    sid = _source(client)
    lot = "LOT-T" + uuid.uuid4().hex[:6].upper()
    body = f"로트식별자,로트명,PLANT_ID,lot_created_quantity\n{lot},테스트,P1,12\n{lot}-B,잘못된 수량,P1,abc\n".encode("cp949")
    r = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": sid, "entity": "lot_master"},
                    files={"file": ("lots.csv", body, "text/csv")})
    assert r.status_code == 200, r.text
    b = r.json()
    assert b["rows"] == 2 and b["columns"][0] == "로트식별자"

    d = client.get(f"/api/admin/batches/{b['batch_id']}", headers=ADMIN).json()
    assert d["suggested_table"] == "lot"
    assert d["suggested_map"]["로트식별자"] == "lot_id" and d["suggested_map"]["PLANT_ID"] == "plant_id"

    r = client.post(f"/api/admin/batches/{b['batch_id']}/standardize", headers=ADMIN,
                    json={"table": "lot", "column_map": d["suggested_map"], "site_id": "HQ"})
    assert r.status_code == 200, r.text
    res = r.json()
    assert (res["rows_in"], res["rows_out"], res["rows_rejected"]) == (2, 1, 1)
    assert res["std_dataset_id"] == "std.lot"
    assert client.get(f"/api/lots/{lot}", headers=ADMIN).status_code == 200

    hist = {x["batch_id"]: x for x in client.get("/api/admin/batches", headers=ADMIN).json()}
    assert hist[b["batch_id"]]["status"] == "STANDARDIZED" and hist[b["batch_id"]]["std_rows_out"] == 1
    ds = client.get(f"/api/admin/datasets/{hist[b['batch_id']]['dataset_id']}", headers=ADMIN).json()
    assert ds["downstream"][0]["dataset_id"] == "std.lot"


def test_xlsx_upload(client):
    sid = _source(client)
    wb = Workbook()
    ws = wb.active
    ws.append(["설비ID", "설비명"])
    ws.append(["EQ-X1", "테스트 설비"])
    buf = io.BytesIO()
    wb.save(buf)
    r = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": sid},
                    files={"file": ("equipment.xlsx", buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
    assert r.status_code == 200, r.text
    assert r.json()["rows"] == 1 and r.json()["entity"] == "equipment"


def test_standardize_rejects_missing_pk(client):
    sid = _source(client)
    r = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": sid},
                    files={"file": ("x.csv", b"name\nfoo\n", "text/csv")})
    r = client.post(f"/api/admin/batches/{r.json()['batch_id']}/standardize", headers=ADMIN,
                    json={"table": "lot", "column_map": {"name": "lot_name"}})
    assert r.status_code == 409 and "기본키" in r.json()["detail"]


def test_upload_to_unknown_source_is_refused(client):
    r = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": "NOPE-404"},
                    files={"file": ("x.csv", b"a\n1\n", "text/csv")})
    assert r.status_code == 409


def test_db_test_only_postgres(client):
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    client.post("/api/admin/sources", headers=ADMIN, json={"source_system_id": sid, "label": "MySQL 원천",
                "system_type": "ERP", "db_kind": "MYSQL", "host": "db.example", "database": "erp", "username": "r"})
    assert client.post(f"/api/admin/sources/{sid}/test", headers=ADMIN, json={"password": "x"}).status_code == 400


def test_db_connect_and_import(client):
    # 원천 DB 대신 레이크 DB 자체에 svc_app 로 붙어 본다 (읽기 전용 트랜잭션)
    from app.config import settings
    from psycopg.conninfo import conninfo_to_dict

    ci = conninfo_to_dict(settings.database_url)
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    r = client.post("/api/admin/sources", headers=ADMIN, json={
        "source_system_id": sid, "label": "레이크 자신", "system_type": "MES", "db_kind": "POSTGRESQL",
        "host": ci.get("host", "localhost"), "port": int(ci.get("port", 5432)), "database": ci["dbname"], "username": ci["user"]})
    assert r.status_code == 200, r.text
    t = client.post(f"/api/admin/sources/{sid}/test", headers=ADMIN, json={"password": ci.get("password", "")}).json()
    assert t["ok"], t
    assert any(x["schema"] == "ksx" and x["name"] == "lot" for x in t["tables"])
    r = client.post(f"/api/admin/sources/{sid}/import", headers=ADMIN,
                    json={"password": ci.get("password", ""), "table": "onto.class", "limit": 5})
    assert r.status_code == 200, r.text
    assert r.json()["rows"] == 5
    src = {s["source_system_id"]: s for s in client.get("/api/admin/sources", headers=ADMIN).json()}[sid]
    assert src["status"] == "OK" and src["datasets"] == 1
