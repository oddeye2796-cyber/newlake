"""접속 풀과 요청 범위 트랜잭션.

모든 요청은 한 트랜잭션 안에서 app.enterprise_id·site_ids·plant_ids·user_id 를 SET LOCAL 한 뒤 실행한다.
RLS(gov.scope_ok)가 이 값으로 행을 거른다. 트랜잭션이 끝나면 값도 사라지므로 풀의 다른 요청으로 새지 않는다.
"""
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field

from psycopg import Connection, sql
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from .config import settings


@dataclass(frozen=True)
class UserContext:
    user_id: str
    display_name: str
    enterprise_id: str
    roles: list[str] = field(default_factory=list)
    site_ids: str = "*"
    plant_ids: str = "*"

    def scope(self) -> dict[str, str]:
        return {
            "app.enterprise_id": self.enterprise_id,
            "app.site_ids": self.site_ids,
            "app.plant_ids": self.plant_ids,
            "app.user_id": self.user_id,
        }


_app_pool: ConnectionPool | None = None
_agent_pool: ConnectionPool | None = None


def _configure(conn: Connection) -> None:
    conn.row_factory = dict_row


def open_pools() -> None:
    global _app_pool, _agent_pool
    # 서버리스(Vercel)·관리형 DB(Neon)에서는 함수가 잠든 사이 DB 쪽이 유휴 접속을 끊는다.
    # 풀이 끊긴 접속을 그대로 내주면 첫 요청이 500 으로 깨지므로, 내주기 전에 살아 있는지 확인하고(check)
    # 오래 논 접속은 미리 버린다(max_idle). 온프레미스에서는 왕복 한 번이 더 드는 정도다.
    common = dict(configure=_configure, open=True, check=ConnectionPool.check_connection,
                  max_idle=settings.pool_max_idle, reconnect_timeout=30.0,
                  kwargs={"connect_timeout": 10, "keepalives": 1, "keepalives_idle": 30,
                          "keepalives_interval": 10, "keepalives_count": 3})
    if _app_pool is None:
        _app_pool = ConnectionPool(settings.database_url, min_size=1, max_size=settings.pool_max, **common)
    if _agent_pool is None:
        _agent_pool = ConnectionPool(settings.agent_database_url, min_size=0, max_size=max(2, settings.pool_max // 4), **common)


def close_pools() -> None:
    global _app_pool, _agent_pool
    for p in (_app_pool, _agent_pool):
        if p is not None:
            p.close()
    _app_pool = _agent_pool = None


def app_pool() -> ConnectionPool:
    open_pools()
    assert _app_pool is not None
    return _app_pool


def agent_pool() -> ConnectionPool:
    open_pools()
    assert _agent_pool is not None
    return _agent_pool


def resolve_user(conn: Connection, user_id: str) -> UserContext | None:
    row = conn.execute("SELECT * FROM gov.user_context(%s)", (user_id,)).fetchone()
    return UserContext(**row) if row else None


def set_scope(conn: Connection, user: UserContext) -> None:
    """svc_app 경로: set_config(…, true) = SET LOCAL."""
    s = user.scope()
    conn.execute(
        "SELECT set_config('app.enterprise_id', %s, true), set_config('app.site_ids', %s, true),"
        " set_config('app.plant_ids', %s, true), set_config('app.user_id', %s, true)",
        (s["app.enterprise_id"], s["app.site_ids"], s["app.plant_ids"], s["app.user_id"]),
    )


@contextmanager
def agent_transaction(user: UserContext) -> Iterator[Connection]:
    """LLM SQL 경로: 읽기 전용 트랜잭션 + SET LOCAL app.* (lake_agent 는 set_config 실행 권한이 없다)."""
    with agent_pool().connection() as conn:
        with conn.transaction():
            conn.execute("SET TRANSACTION READ ONLY")
            for k, v in user.scope().items():
                conn.execute(sql.SQL("SET LOCAL {} = {}").format(sql.SQL(k), sql.Literal(v)))
            # gov.run_agent_query 는 current_user = lake_agent 를 요구한다 (접속 계정 svc_agent 는 그 멤버)
            conn.execute("SET LOCAL ROLE lake_agent")
            yield conn


def audit(conn: Connection, action: str, object_ref: str | None = None, *, channel: str = "UI",
          query_text: str | None = None, row_count: int | None = None, result: str = "OK") -> None:
    conn.execute(
        "INSERT INTO gov.audit_log (channel, action, object_ref, query_text, row_count, result)"
        " VALUES (%s, %s, %s, %s, %s, %s)",
        (channel, action, object_ref, query_text, row_count, result),
    )
