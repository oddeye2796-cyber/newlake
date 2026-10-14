"""API 테스트는 실제 PostgreSQL 에 붙는다 (RLS·권한을 흉내 내면 의미가 없다).

필요: db/init_dev.sh 로 준비한 DB. 접속 정보는 LAKE_DATABASE_URL·LAKE_AGENT_DATABASE_URL.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture(scope="session")
def client():
    with TestClient(app) as c:
        yield c


def as_user(user_id: str) -> dict[str, str]:
    return {"X-User-Id": user_id}


@pytest.fixture(scope="session")
def fresh_hold(client) -> str:
    """승인 테스트용 '로트 보류' 제안을 새로 하나 만든다 (여러 번 돌려도 같은 결과가 나오게).
    lake_app 은 action_execution 에 INSERT(제안)만 할 수 있고 상태 변경은 gov.decide_action 으로만 된다."""
    from app.db import app_pool, resolve_user, set_scope

    with app_pool().connection() as conn, conn.transaction():
        user = resolve_user(conn, "u-jung")
        set_scope(conn, user)
        row = conn.execute(
            "INSERT INTO gov.action_execution (policy_id, risk_event_id, site_id, plant_id, action_iri, target_iri, verb, noun, requested_by)"
            " VALUES ('otd-risk', '00000000-0000-4000-8000-000000000731', 'HQ', 'P1',"
            "         'https://ontology.impix.co.kr/arcon/HoldLot', 'https://data.impix.co.kr/ACME/lot/LOT-2026-0731',"
            "         'Change', 'Lot', 'u-jung') RETURNING execution_id::text").fetchone()
    return row["execution_id"]
