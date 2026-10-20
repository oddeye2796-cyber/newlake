"""온톨로지 확장 3차 — 확장 클래스·속성·관계 CRUD, 버전 발행, 적재 시 확장 속성 보관·제안·자동 품질 검증, 배치 되돌리기."""
import io
import uuid
from datetime import date

from openpyxl import Workbook

from .conftest import as_user

ADMIN = as_user("u-choi")        # admin + data_steward
ANALYST = as_user("u-jung")
ARCON = "https://ontology.impix.co.kr/arcon/"
KSX = "https://ontology.impix.co.kr/ksx9101/"
XSD = "http://www.w3.org/2001/XMLSchema#"


def test_ext_class_property_link_and_publish(client):
    tag = uuid.uuid4().hex[:6]
    cls, prop, ref = f"Coil{tag}", f"coilThickness{tag}", f"coilOf{tag}"
    assert client.put(f"/api/admin/ontology/ext/classes/{cls}", headers=ANALYST, json={"label_ko": "코일"}).status_code == 403
    assert client.put("/api/admin/ontology/ext/classes/bad name", headers=ADMIN, json={"label_ko": "코일"}).status_code == 409
    r = client.put(f"/api/admin/ontology/ext/classes/{cls}", headers=ADMIN,
                   json={"label_ko": "코일 (테스트)", "label_en": "Coil", "business_group": "생산", "parent_class_iri": KSX + "Lot", "definition_ko": "압연 코일 단위"})
    assert r.status_code == 200, r.text
    assert r.json()["class_iri"] == ARCON + cls

    # 값 속성: xsd 짧은 이름을 받아 준다. 잘못된 형은 400
    assert client.put(f"/api/admin/ontology/ext/properties/{prop}", headers=ADMIN,
                      json={"kind": "DATATYPE", "label_ko": "두께", "domain_class_iri": ARCON + cls, "range_iri": "money"}).status_code == 400
    r = client.put(f"/api/admin/ontology/ext/properties/{prop}", headers=ADMIN,
                   json={"kind": "DATATYPE", "label_ko": "두께", "domain_class_iri": ARCON + cls, "range_iri": "decimal", "unit": "mm"})
    assert r.status_code == 200, r.text
    # 참조 속성은 관계(link)도 함께 만든다
    r = client.put(f"/api/admin/ontology/ext/properties/{ref}", headers=ADMIN,
                   json={"kind": "OBJECT", "label_ko": "코일의 로트", "domain_class_iri": ARCON + cls, "range_iri": KSX + "Lot"})
    assert r.status_code == 200, r.text

    ext = client.get("/api/admin/ontology/extensions", headers=ADMIN).json()
    c = next(x for x in ext["classes"] if x["local_name"] == cls)
    assert c["parent_label"] == "로트" and c["properties"] == 2 and c["version_id"] is None
    p = next(x for x in ext["properties"] if x["local_name"] == prop)
    assert p["range_iri"] == XSD + "decimal" and p["unit"] == "mm" and p["domain_label"] == "코일 (테스트)"
    link = next(x for x in ext["links"] if x["property_name"] == ref)
    assert link["subject_label"] == "코일 (테스트)" and link["object_label"] == "로트" and link["relation_kind"] == "확장 참조"
    assert ext["unpublished"] >= 3

    # 관계 지우고 다시 만들기
    assert client.delete(f"/api/admin/ontology/ext/links/{link['link_id']}", headers=ADMIN).status_code == 200
    r = client.post("/api/admin/ontology/ext/links", headers=ADMIN,
                    json={"subject_class_iri": ARCON + cls, "property_iri": ARCON + ref, "object_class_iri": KSX + "Lot", "relation_kind": "확장 참조"})
    assert r.status_code == 200, r.text
    again = client.post("/api/admin/ontology/ext/links", headers=ADMIN,
                        json={"subject_class_iri": ARCON + cls, "property_iri": ARCON + ref, "object_class_iri": KSX + "Lot"})
    assert again.status_code == 200 and again.json()["link_id"] == r.json()["link_id"]   # 같은 세 짝은 하나만

    # 버전 발행: 아직 버전이 없는 확장 클래스·속성에 버전이 찍힌다
    r = client.post("/api/admin/ontology/versions/publish", headers=ADMIN, json={"version_info": "t-" + tag, "note": "테스트 발행"})
    assert r.status_code == 200, r.text
    v = r.json()
    assert v["version_id"].startswith("arcon-t-" + tag) and v["classes"] >= 1 and v["properties"] >= 2
    ext = client.get("/api/admin/ontology/extensions", headers=ADMIN).json()
    assert next(x for x in ext["classes"] if x["local_name"] == cls)["version_id"] == v["version_id"]
    assert next(x for x in ext["versions"] if x["version_id"] == v["version_id"])["status"] == "RELEASED"
    assert ext["unpublished"] == 0
    assert client.post("/api/admin/ontology/versions/publish", headers=ADMIN, json={"version_info": "t2-" + tag}).status_code == 409

    # 담긴 것이 있는 버전은 못 지운다
    assert client.delete(f"/api/admin/ontology/versions/{v['version_id']}", headers=ADMIN).status_code == 409
    # 표준 클래스·속성은 못 지운다. 속성이 달린 클래스도 못 지운다
    assert client.delete("/api/admin/ontology/ext/classes/Lot", headers=ADMIN).status_code == 409
    assert client.delete(f"/api/admin/ontology/ext/classes/{cls}", headers=ADMIN).status_code == 409
    assert client.delete(f"/api/admin/ontology/ext/properties/{prop}", headers=ADMIN).status_code == 200
    assert client.delete(f"/api/admin/ontology/ext/properties/{ref}", headers=ADMIN).status_code == 200
    assert client.delete(f"/api/admin/ontology/ext/classes/{cls}", headers=ADMIN).status_code == 200
    assert client.delete(f"/api/admin/ontology/ext/classes/{cls}", headers=ADMIN).status_code == 409
    assert any(a["action"] == "publish_ontology_version" for a in client.get("/api/admin/audit?action=publish_ontology_version", headers=ADMIN).json())
    # 비게 된 버전은 지울 수 있다 (표준 코어 버전은 안 됨). 다른 미발행 확장이 함께 담겼으면 비지 않아 409
    assert client.delete(f"/api/admin/ontology/versions/{v['version_id']}", headers=ADMIN).status_code == (200 if (v["classes"], v["properties"]) == (1, 2) else 409)
    assert client.delete(f"/api/admin/ontology/versions/{v['version_id']}", headers=ADMIN).status_code == 409
    assert client.delete("/api/admin/ontology/versions/ksx9101-2025-v1.0-gen-0.2.0", headers=ADMIN).status_code == 409


def _po_batch(client, tag: str, qty2: int = 500, thick: str = "두께", memo: str = "비고") -> str:
    sid = "T-" + uuid.uuid4().hex[:8].upper()
    client.post("/api/admin/sources", headers=ADMIN, json={"source_system_id": sid, "label": "확장 테스트", "system_type": "SCM", "db_kind": "FILE"})
    wb = Workbook()
    ws = wb.active
    ws.append(["납품요청일", "발주번호", "업체명", "품번", "품명", thick, "폭", "발주수량", memo, "비고"])
    ws.append([date(2026, 10, 1), f"SX{tag}01", "(주)두원", f"X{tag}1", "STS304", 0.4, 285.0, 1000, "긴급", None])
    ws.append([date(2026, 10, 2), f"SX{tag}02", "(주)대한", f"X{tag}2", "STS430", 0.5, 300.0, qty2, "일반", None])
    buf = io.BytesIO()
    wb.save(buf)
    r = client.post("/api/admin/upload", headers=ADMIN, data={"source_system_id": sid},
                    files={"file": ("po.xlsx", buf.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")})
    assert r.status_code == 200, r.text
    return r.json()["batch_id"]


def test_standardize_keeps_extras_proposes_and_checks_quality(client):
    tag = uuid.uuid4().hex[:6].upper()
    thick, memo = "두께" + tag, "메모" + tag     # 이전 실행의 승인 결과와 섞이지 않게 열 이름에 꼬리표
    bid = _po_batch(client, tag, thick=thick, memo=memo)
    d = client.get(f"/api/admin/batches/{bid}", headers=ADMIN).json()
    m = d["suggested_map"]
    assert thick not in m and "폭" not in m and "업체명" not in m
    r = client.post(f"/api/admin/batches/{bid}/standardize", headers=ADMIN,
                    json={"table": "purchase_order_line", "column_map": m, "site_id": "HQ", "plant_id": "P1", "create_refs": True})
    assert r.status_code == 200, r.text
    res = r.json()
    assert res["rows_out"] == 2
    # 1) 자리 없는 열은 확장 속성으로 보관 (빈 열 '비고'는 제외)
    assert res["extensions"]["columns"] == 4 and res["extensions"]["rows"] == 8
    ea = client.get("/api/admin/extension-attributes?table=purchase_order_line", headers=ADMIN).json()
    names = {x["attr_name"] for x in ea["summary"]}
    assert {thick, memo, "폭", "업체명"} <= names and any(x["attr_name"] == thick and x["attr_value"] == "0.4" for x in ea["rows"])
    # 2) 확장 제안이 쌓인다 (두께 → thickness decimal mm). 이미 승인된 열(이전 실행)은 다시 묻지 않으므로 꼬리표 열만 센다
    assert res["proposals"] >= 2
    props = {p["column_name"]: p for p in client.get("/api/admin/ontology/proposals", headers=ADMIN).json() if p["batch_id"] == bid}
    th = props[thick]
    assert th["suggested_local_name"] == "thickness" and th["suggested_range_iri"] == XSD + "decimal" and th["unit"] == "mm"
    assert th["target_label"] == "구매발주라인" and th["status"] == "PROPOSED"
    # 3) 켜진 SQL 규칙이 자동으로 돌았다
    q = {x["rule_id"]: x for x in res["quality"]}
    assert q["po-quantity-positive"]["status"] == "OK" and q["po-item-known"]["status"] == "OK"
    assert q["po-quantity-positive"]["conformance_rate"] == 100

    # 제안 승인: 이름·형을 고쳐서 승인하면 확장 속성이 생기고 보관된 값에 이어진다
    local = f"thickness{tag.lower()}"
    r = client.post(f"/api/admin/ontology/proposals/{th['proposal_id']}/decide", headers=ADMIN,
                    json={"accept": True, "local_name": local, "label_ko": "두께 (mm)", "range_iri": "decimal", "unit": "mm"})
    assert r.status_code == 200, r.text
    assert r.json() == {"status": "ACCEPTED", "result_iri": ARCON + local}
    assert client.post(f"/api/admin/ontology/proposals/{th['proposal_id']}/decide", headers=ADMIN, json={"accept": True}).status_code == 409
    ea = client.get("/api/admin/extension-attributes?table=purchase_order_line", headers=ADMIN).json()
    assert next(x for x in ea["summary"] if x["attr_name"] == thick)["property_name"] == local
    # 반려 (분석가는 못 한다)
    assert client.post(f"/api/admin/ontology/proposals/{props[memo]['proposal_id']}/decide", headers=ANALYST, json={"accept": False}).status_code == 403
    r = client.post(f"/api/admin/ontology/proposals/{props[memo]['proposal_id']}/decide", headers=ADMIN, json={"accept": False})
    assert r.json()["status"] == "REJECTED"
    # 값이 보관된 확장 속성은 못 지운다
    assert client.delete(f"/api/admin/ontology/ext/properties/{local}", headers=ADMIN).status_code == 409

    # 다음 배치: 같은 열은 새 확장 속성에 바로 이어지고 다시 묻지 않는다. 수량 0 은 자동 품질 검증에 걸린다
    bid2 = _po_batch(client, tag + "B", qty2=0, thick=thick, memo=memo)
    m2 = client.get(f"/api/admin/batches/{bid2}", headers=ADMIN).json()["suggested_map"]
    res2 = client.post(f"/api/admin/batches/{bid2}/standardize", headers=ADMIN,
                       json={"table": "purchase_order_line", "column_map": m2, "site_id": "HQ", "plant_id": "P1", "create_refs": True}).json()
    assert res2["rows_out"] == 2 and res2["extensions"]["matched"] >= 1
    q2 = {x["rule_id"]: x for x in res2["quality"]}
    assert q2["po-quantity-positive"]["status"] == "VIOLATED" and q2["po-quantity-positive"]["violation_count"] == 1
    viol = client.get("/api/admin/quality", headers=ADMIN).json()["violations"]
    assert any(v["rule_id"] == "po-quantity-positive" and v["focus_node"] == f"SX{tag}B02-1" for v in viol)

    # 되돌리기: 이 배치의 표준 행·확장 값이 빠지고 배치는 LANDED 로 돌아간다
    r = client.post(f"/api/admin/batches/{bid2}/rollback", headers=ADMIN)
    assert r.status_code == 200, r.text
    rb = r.json()
    assert rb["rows"] == 2 and rb["extension_rows"] >= 8 and rb["table"] == "ksx.purchase_order_line"
    hist = {x["batch_id"]: x for x in client.get("/api/admin/batches", headers=ADMIN).json()}
    assert hist[bid2]["status"] == "LANDED"
    assert client.post(f"/api/admin/batches/{bid2}/rollback", headers=ADMIN).status_code == 409
    assert client.post(f"/api/admin/batches/{bid2}/rollback", headers=ANALYST).status_code == 403
    # 다른 배치 행은 남아 있다
    assert client.get(f"/api/admin/extension-attributes?table=purchase_order_line", headers=ADMIN).json()["summary"]
    # 끄면 보관·제안·검증을 하지 않는다
    res3 = client.post(f"/api/admin/batches/{bid2}/standardize", headers=ADMIN,
                       json={"table": "purchase_order_line", "column_map": m2, "site_id": "HQ", "plant_id": "P1", "keep_extras": False, "auto_quality": False}).json()
    assert res3["rows_out"] == 2 and res3["extensions"] is None and res3["proposals"] == 0 and res3["quality"] == []

    # 정리: 두 배치를 되돌리면 보관 값이 없어져 확장 속성을 지울 수 있다
    assert client.post(f"/api/admin/batches/{bid2}/rollback", headers=ADMIN).json()["rows"] == 2
    assert client.post(f"/api/admin/batches/{bid}/rollback", headers=ADMIN).json()["extension_rows"] == 8
    assert client.delete(f"/api/admin/ontology/ext/properties/{local}", headers=ADMIN).status_code == 200
