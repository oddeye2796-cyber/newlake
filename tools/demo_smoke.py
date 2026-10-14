"""시연 사이트에서 데이터 넣기 → 확장 제안 흐름을 실제로 한 번 돌려 본다 (표준 라이브러리만 사용).

사용: python3 tools/demo_smoke.py https://newlake.vercel.app [u-choi]
  1) 원천(SCM, 파일) 등록 → 2) 표준에 없는 열(두께·폭·업체명·메모)이 든 발주 CSV 올리기
  3) 자동 대응으로 표준 존에 넣기(남는 열 보관·품질 검증 켬) → 4) 확장 제안 중 두께는 승인, 메모는 반려
  5) 확장 속성 요약과 적재 기록을 읽어 결과를 요약해 출력한다.
  6) 실제 MES·SCM 내보내기와 같은 구조의 고정 파일(api/tests/fixtures/*.xlsx, 가짜 행) 두 개를 올려
     생산실적·구매발주 표로 자동 대응되고 표준 존에 들어가는지 본다.
시연 DB 에만 쓴다. 매번 꼬리표가 다른 발주번호를 넣으므로 반복 실행해도 겹치지 않는다.
"""
import json
import pathlib
import sys
import urllib.error
import urllib.request
import uuid

BASE = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "https://newlake.vercel.app"
USER = sys.argv[2] if len(sys.argv) > 2 else "u-choi"


def call(method: str, path: str, body=None, files=None):
    headers = {"X-User-Id": USER}
    if files is not None:
        boundary = "----newlake" + uuid.uuid4().hex
        parts = b""
        for k, v in body.items():
            parts += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode()
        name, data = files
        ctype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" if name.endswith(".xlsx") else "text/csv"
        parts += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\n"
                  f"Content-Type: {ctype}\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        payload = parts
    elif body is not None:
        headers["Content-Type"] = "application/json"
        payload = json.dumps(body, ensure_ascii=False).encode()
    else:
        payload = None
    req = urllib.request.Request(BASE + path, data=payload, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "null")


def must(status: int, data, what: str):
    if status != 200:
        print(f"!! {what}: HTTP {status} {json.dumps(data, ensure_ascii=False)[:500]}")
        sys.exit(1)
    return data


tag = uuid.uuid4().hex[:6].upper()
sid = "SCM-DEMO"
st, _ = call("GET", "/api/health")
must(st, _, "health")

# 1) 원천
st, d = call("POST", "/api/admin/sources", {"source_system_id": sid, "label": "SCM 시연 파일", "system_type": "SCM", "db_kind": "FILE"})
if st not in (200, 409):
    must(st, d, "원천 등록")

# 2) 표준에 없는 열이 든 발주 CSV (두께·폭·업체명·메모). 세 번째 행은 수량 0 → 품질 규칙 위반 예시
csv = "﻿납품요청일,발주번호,업체명,품번,품명,두께,폭,발주수량,메모\n" + "\n".join([
    f"2026-10-01,SX{tag}01,(주)두원,X{tag}1,STS304,0.4,285,1000,긴급",
    f"2026-10-02,SX{tag}02,(주)대한,X{tag}2,STS430,0.5,300,500,일반",
    f"2026-10-03,SX{tag}03,(주)두원,X{tag}3,STS304,0.6,310,0,수량 확인 필요",
]) + "\n"
st, up = call("POST", "/api/admin/upload", {"source_system_id": sid, "entity": f"purchase_order_{tag}"},
              files=(f"발주_{tag}.csv", csv.encode("utf-8")))
must(st, up, "파일 올리기")
bid = up["batch_id"]

# 3) 자동 대응 → 표준 존
st, pv = call("GET", f"/api/admin/batches/{bid}")
must(st, pv, "미리보기")
cmap = pv["suggested_map"]
table = pv.get("suggested_table") or "purchase_order"
st, res = call("POST", f"/api/admin/batches/{bid}/standardize",
               {"table": table, "column_map": cmap, "site_id": "HQ", "plant_id": "P1",
                "create_refs": True, "keep_extras": True, "auto_quality": True})
must(st, res, "표준 존 변환")

# 4) 확장 제안: 두께 승인, 메모 반려, 나머지는 대기열에 남겨 둔다
st, props = call("GET", "/api/admin/ontology/proposals?status=PROPOSED")
must(st, props, "제안 목록")
mine = {p["column_name"]: p for p in props if p.get("batch_id") == bid or p.get("std_table") == "purchase_order"}
decided = {}
if "두께" in mine:
    st, d = call("POST", f"/api/admin/ontology/proposals/{mine['두께']['proposal_id']}/decide",
                 {"accept": True, "local_name": mine["두께"].get("suggested_local_name") or "thickness", "label_ko": "두께 (mm)",
                  "range_iri": "decimal", "unit": "mm"})
    decided["두께"] = (st, d if st != 200 else d.get("property_iri") or d.get("local_name") or "accepted")
if "메모" in mine:
    st, d = call("POST", f"/api/admin/ontology/proposals/{mine['메모']['proposal_id']}/decide", {"accept": False})
    decided["메모"] = (st, "rejected" if st == 200 else d)

# 5) 확인
st, ea = call("GET", "/api/admin/extension-attributes?table=purchase_order&limit=5")
must(st, ea, "확장 속성")
st, left = call("GET", "/api/admin/ontology/proposals?status=PROPOSED")

# 6) 실제 내보내기 구조의 고정 파일 (가짜 행): MES 실적 → 생산실적, SCM 발주 → 구매발주
FIX = pathlib.Path(__file__).resolve().parent.parent / "api" / "tests" / "fixtures"
samples = {}
for src_id, label, typ, fname, want in (("MES-DEMO", "MES 시연 파일", "MES", "mes_treegrid_export.xlsx", "production_performance"),
                                        (sid, None, None, "scm_po_export.xlsx", "purchase_order")):
    if label:
        st, d = call("POST", "/api/admin/sources", {"source_system_id": src_id, "label": label, "system_type": typ, "db_kind": "FILE"})
        if st not in (200, 409):
            must(st, d, f"원천 등록 {src_id}")
    st, u = call("POST", "/api/admin/upload", {"source_system_id": src_id}, files=(fname, (FIX / fname).read_bytes()))
    must(st, u, f"고정 파일 올리기 {fname}")
    st, p = call("GET", f"/api/admin/batches/{u['batch_id']}")
    must(st, p, f"미리보기 {fname}")
    st, r = call("POST", f"/api/admin/batches/{u['batch_id']}/standardize",
                 {"table": p["suggested_table"], "column_map": p["suggested_map"], "site_id": "HQ", "plant_id": "P1",
                  "create_refs": True, "keep_extras": True, "auto_quality": True})
    must(st, r, f"표준 존 변환 {fname}")
    samples[fname] = {"rows": u["rows"], "columns": len(u["columns"]), "suggested_table": p["suggested_table"], "table_ok": p["suggested_table"] == want,
                      "mapped": len(p["suggested_map"]), "rows_out": r.get("rows_out"), "rows_rejected": r.get("rows_rejected"),
                      "extensions": r.get("extensions"), "proposals": r.get("proposals"), "errors": r.get("errors")}

print(json.dumps({
    "batch_id": bid, "tag": tag, "table": table, "rows_out": res.get("rows_out"), "rows_rejected": res.get("rows_rejected"),
    "column_map": cmap, "extensions": res.get("extensions"), "proposals_created": res.get("proposals"),
    "quality": res.get("quality"), "decided": decided,
    "ext_attr_summary": [(x["attr_name"], x.get("rows")) for x in ea.get("summary", [])],
    "proposals_pending": [(p["column_name"], p.get("suggested_local_name")) for p in (left or [])],
    "samples": samples,
}, ensure_ascii=False, indent=1, default=str))
if not all(x["table_ok"] and x["rows_rejected"] == 0 for x in samples.values()):
    print("!! 고정 파일이 기대한 표로 가지 않았거나 거부된 행이 있습니다")
    sys.exit(1)
