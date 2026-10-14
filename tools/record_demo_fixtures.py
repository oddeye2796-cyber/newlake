#!/usr/bin/env python3
"""미리보기(GitHub Pages)용 API 응답 녹화.

개발 DB(db/init_dev.sh)에 붙은 API 서버에서 화면이 부르는 응답을 사용자별로 받아 web/src/demo/fixtures.json 에 저장한다.
사용: python3 tools/record_demo_fixtures.py [API 주소, 기본 http://localhost:8000]
녹화 전에 승인 대기 건이 남아 있게 시드를 다시 넣어 두면 미리보기에서 승인 흐름을 볼 수 있다.
"""
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
USERS = ["u-jung", "u-kim", "u-lee", "u-choi"]
ADMIN_USERS = {"u-choi"}
Q = urllib.parse.quote


def req(user, path, body=None):
    r = urllib.request.Request(BASE + path, data=json.dumps(body).encode() if body else None,
                               headers={"X-User-Id": user, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r) as f:
            return [f.status, json.load(f)]
    except urllib.error.HTTPError as e:
        return [e.code, json.load(e)]


presets = re.findall(r"sql: `(.*?)`", (ROOT / "web/src/askPresets.ts").read_text(), re.S)
GETS = ["/api/me", "/api/home", "/api/inbox", "/api/inbox?status=ALL", "/api/kpi/otd", "/api/kpi/ppm", "/api/kpi/risks",
        "/api/kpi/utilization?days=30", "/api/kpi/wip", "/api/kpi/yield", "/api/catalog/datasets"]
ADMIN_GETS = ["/api/admin/overview", "/api/admin/datasets", "/api/admin/ontology/classes", "/api/admin/lineage",
              "/api/admin/quality", "/api/admin/access", "/api/admin/audit", "/api/admin/audit?limit=100"]

out = {"get": {}, "query": {}}
for u in USERS:
    paths = list(GETS) + ADMIN_GETS
    hits = []
    for q in ["LOT-", "EQ-", "SO-", "ITM-", "C-"]:
        paths.append("/api/search?q=" + Q(q))
        hits += req(u, "/api/search?q=" + Q(q))[1]["results"]
    for h in hits:
        paths.append("/api/search?q=" + Q(h["id"]))
        if h["kind"] == "lot":
            paths.append("/api/lots/" + Q(h["id"]))
        if h["kind"] == "equipment":
            paths += [f"/api/equipment/{Q(h['id'])}?days={d}" for d in (1, 7, 30)]
    if u in ADMIN_USERS:
        for z in ["RAW", "STANDARD", "SEMANTIC", "CURATED"]:
            paths.append(f"/api/admin/datasets?zone={z}")
        paths += ["/api/admin/datasets/" + Q(d["dataset_id"]) for d in req(u, "/api/admin/datasets")[1]]
        paths += ["/api/admin/ontology/classes/" + Q(c["local_name"]) for c in req(u, "/api/admin/ontology/classes")[1]]
    for p in dict.fromkeys(paths):
        out["get"][f"{u}|{p}"] = req(u, p)
    for sql in presets:
        out["query"][f"{u}|{sql}"] = req(u, "/api/agent/query", {"sql": sql})

dest = ROOT / "web/src/demo/fixtures.json"
dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
print(f"{dest}: GET {len(out['get'])}건, 질의 {len(out['query'])}건, {dest.stat().st_size // 1024} KB")
