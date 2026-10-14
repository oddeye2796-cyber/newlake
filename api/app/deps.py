from collections.abc import Iterator
from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException
from psycopg import Connection

from .config import settings
from .db import UserContext, app_pool, resolve_user, set_scope


@dataclass
class Scoped:
    conn: Connection
    user: UserContext


def _user_id(x_user_id: str | None = Header(default=None)) -> str:
    if not settings.dev_auth:
        # 운영: OIDC 토큰 검증 미들웨어가 들어올 자리
        raise HTTPException(501, "운영 인증이 아직 연결되지 않았습니다 (LAKE_DEV_AUTH=false)")
    return x_user_id or settings.dev_default_user


def scoped(user_id: str = Depends(_user_id)) -> Iterator[Scoped]:
    """요청 하나 = 트랜잭션 하나. 사용자 범위를 SET LOCAL 하고, 예외가 나면 되돌린다."""
    with app_pool().connection() as conn:
        with conn.transaction():
            user = resolve_user(conn, user_id)
            if user is None:
                raise HTTPException(401, f"사용자 {user_id} 를 찾을 수 없거나 비활성입니다")
            set_scope(conn, user)
            yield Scoped(conn, user)
