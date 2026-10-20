"""V0015 품질 검증 바로잡기: 위반 이어 가기 · 데이터셋 품질 종합 · 시맨틱 존 게이트."""
import uuid

import psycopg
import pytest

from .conftest import as_user
from .test_steward import _raw_dataset

ADMIN = as_user("u-choi")


def _rule(client, rid, ds, rows, threshold=90, enabled=True):
    sql = " UNION ALL ".join(f"SELECT '{fn}' AS focus_node, 'p' AS result_path, '확인 {fn}' AS message" for fn in rows) or \
        "SELECT 'x' AS focus_node, 'p' AS result_path, 'm' AS message WHERE false"
    body = {"label_ko": "V0015 " + rid, "dimension": "완전성", "target_dataset_id": ds, "severity": "Warning", "threshold": threshold,
            "enabled": enabled, "sql_check": sql}
    r = client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json=body)
    assert r.status_code == 200, r.text


def _run(client, rid):
    r = client.post(f"/api/admin/quality/rules/{rid}/run", headers=ADMIN)
    assert r.status_code == 200, r.text
    return r.json()


def _viol(client, rid):
    return {v["focus_node"]: v for v in client.get("/api/admin/quality", headers=ADMIN).json()["violations"] if v["rule_id"] == rid}


def test_rerun_carries_open_violations_instead_of_duplicating(client):
    rid = "t-carry-" + uuid.uuid4().hex[:6]
    _, ds = _raw_dataset(client)
    _rule(client, rid, ds, ["X1", "X2"])
    out = _run(client, rid)
    assert out["new_violations"] == 2 and out["carried_violations"] == 0 and out["auto_resolved"] == 0
    v = _viol(client, rid)
    client.put(f"/api/admin/quality/violations/{v['X1']['violation_id']}", headers=ADMIN, json={"status": "ACK", "assignee_user_id": "u-kim"})

    # 다시 돌림: X1 은 그대로 이어지고(상태·담당 유지), X2 는 사라져 자동 해결, X3 은 새 위반
    _rule(client, rid, ds, ["X1", "X3"])
    out = _run(client, rid)
    assert (out["new_violations"], out["carried_violations"], out["auto_resolved"]) == (1, 1, 1)
    v = _viol(client, rid)
    assert set(v) == {"X1", "X2", "X3"}
    assert v["X1"]["status"] == "ACK" and v["X1"]["assignee_user_id"] == "u-kim" and v["X2"]["status"] == "FIXED" and v["X3"]["status"] == "OPEN"
    rows = [x for x in client.get("/api/admin/quality", headers=ADMIN).json()["violations"] if x["rule_id"] == rid]
    assert len(rows) == 3    # 같은 대상이 두 번 쌓이지 않는다

    # 예외 처리한 행은 또 나와도 다시 열지 않는다
    client.put(f"/api/admin/quality/violations/{v['X3']['violation_id']}", headers=ADMIN, json={"status": "WAIVED"})
    out = _run(client, rid)
    assert (out["new_violations"], out["carried_violations"], out["waived_skipped"]) == (0, 1, 1)
    assert out["violation_count"] == 2       # 실행 기록의 위반 수는 검사식이 찾은 그대로
    rows = [x for x in client.get("/api/admin/quality", headers=ADMIN).json()["violations"] if x["rule_id"] == rid]
    assert sorted((x["focus_node"], x["status"]) for x in rows) == [("X1", "ACK"), ("X2", "FIXED"), ("X3", "WAIVED")]
    client.put(f"/api/admin/quality/rules/{rid}", headers=ADMIN, json={"label_ko": "끔", "dimension": "완전성", "target_dataset_id": ds,
                                                                     "severity": "Warning", "enabled": False, "sql_check": "SELECT 1"})


def test_dataset_quality_combines_all_rules(client):
    tag = uuid.uuid4().hex[:6]
    bad, good = "t-bad-" + tag, "t-good-" + tag
    _, ds = _raw_dataset(client)
    _rule(client, bad, ds, ["A1"], threshold=90)      # 대상 2건 중 1건 → 50%, 기준 미달
    _rule(client, good, ds, [], threshold=90)
    _run(client, bad)
    _run(client, good)                                # 예전엔 마지막에 돈 이 규칙(100%)이 점수를 덮어썼다
    d = client.get(f"/api/admin/datasets/{ds}", headers=ADMIN).json()
    assert d["dataset"]["quality_status"] == "FAIL" and d["dataset"]["quality_score"] == 50
    assert [q["rule_id"] for q in d["quality_rules"]] == [bad, good]

    # 기준 미달 규칙을 끄면 남은 규칙으로 다시 종합한다
    client.put(f"/api/admin/quality/rules/{bad}", headers=ADMIN, json={"label_ko": "끔", "dimension": "완전성", "target_dataset_id": ds,
                                                                     "severity": "Warning", "threshold": 90, "enabled": False, "sql_check": "SELECT 1"})
    d = client.get(f"/api/admin/datasets/{ds}", headers=ADMIN).json()
    assert d["dataset"]["quality_status"] == "PASS" and d["dataset"]["quality_score"] == 100


def _owner():
    try:
        return psycopg.connect(dbname="lake", connect_timeout=3)
    except psycopg.Error:
        pytest.skip("스키마 소유 계정(PG* 환경 변수)으로 접속할 수 없어 시맨틱 게이트 시험을 건너뜀")


def test_semantic_gate_blocks_failed_sources(client):
    rid = "t-gate-" + uuid.uuid4().hex[:6]
    with _owner() as oc:
        pid, src = "t-sem-" + rid, None
        _, src = _raw_dataset(client)
        oc.execute("INSERT INTO catalog.pipeline (pipeline_id, label_ko, from_zone, to_zone, engine, enabled) VALUES (%s, '시험 KG', 'STANDARD', 'SEMANTIC', 'morph-kgc', true)", (pid,))
        oc.execute("INSERT INTO catalog.lineage_edge (from_dataset_id, to_dataset_id, pipeline_id) VALUES (%s, 'sem.abox.acme_hq_p1', %s)", (src, pid))
        oc.commit()
        _rule(client, rid, src, ["G1", "G2"], threshold=99)
        _run(client, rid)
        blocked = client.get("/api/admin/quality", headers=ADMIN).json()["semantic_blocked"]
        assert any(b["pipeline_id"] == pid and b["dataset_id"] == src for b in blocked)
        with pytest.raises(psycopg.errors.CheckViolation, match="시맨틱 존 반영"):
            oc.execute("INSERT INTO catalog.job_run (pipeline_id, status, enterprise_id) VALUES (%s, 'RUNNING', 'ACME')", (pid,))
        oc.rollback()
        # 지난 기록 옮겨 싣기(RUNNING 이 아닌 상태)는 막지 않는다
        oc.execute("INSERT INTO catalog.job_run (pipeline_id, status, enterprise_id, ended_at) VALUES (%s, 'SUCCESS', 'ACME', now())", (pid,))
        oc.rollback()
        # 위반이 사라지면 풀린다
        _rule(client, rid, src, [], threshold=99)
        _run(client, rid)
        assert not any(b["pipeline_id"] == pid for b in client.get("/api/admin/quality", headers=ADMIN).json()["semantic_blocked"])
        oc.execute("INSERT INTO catalog.job_run (pipeline_id, status, enterprise_id) VALUES (%s, 'RUNNING', 'ACME')", (pid,))
        oc.rollback()
        oc.execute("UPDATE catalog.pipeline SET enabled = false WHERE pipeline_id = %s", (pid,))
        oc.commit()
