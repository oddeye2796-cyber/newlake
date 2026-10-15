import re

import psycopg
from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from ..config import settings
from ..db import agent_transaction, audit
from ..deps import Scoped, scoped

router = APIRouter(prefix="/api/agent", tags=["agent"])

_DENIED = (psycopg.errors.RaiseException, psycopg.errors.InsufficientPrivilege, psycopg.errors.ReadOnlySqlTransaction)


# 질의 작업대에서 자주 나는 PostgreSQL 오류를 사람이 읽는 말로 (원문은 raw 로 함께 돌려준다)
_FRIENDLY = {
    "42P01": "표가 없습니다{q}. 스키마 이름(ksx.·mart.)까지 적었는지, 카탈로그에서 표 이름을 확인하세요",
    "42703": "열이 없습니다{q}. 카탈로그 → 스키마 탭에서 열 이름을 확인하세요",
    "42702": "열 이름이 여러 표에 있어 어느 것인지 모릅니다{q}. 표 별칭을 붙여 주세요 (예: l.lot_id)",
    "42601": "SQL 문법이 맞지 않습니다{at}",
    "42883": "그런 함수가 없거나 값의 형이 맞지 않습니다. 형 변환(::numeric 등)을 확인하세요",
    "42803": "GROUP BY 에 넣지 않은 열을 골랐습니다. 그 열을 GROUP BY 에 넣거나 집계 함수로 감싸세요",
    "42804": "값의 형이 맞지 않습니다. 형 변환(::text, ::numeric 등)을 확인하세요",
    "42501": "이 표나 함수는 질의 작업대에서 쓸 수 없습니다",
    "25006": "질의 작업대는 조회(SELECT)만 할 수 있습니다",
    "57014": "시간이 너무 오래 걸려 멈췄습니다. 조건을 좁히거나 LIMIT 을 붙여 보세요",
    "22P02": "값의 모양이 형에 맞지 않습니다{q}",
    "22007": "날짜·시간 모양이 맞지 않습니다{q}",
    "22008": "날짜·시간 범위를 벗어났습니다",
    "22012": "0 으로 나눴습니다. NULLIF(분모, 0) 을 써 보세요",
    "21000": "하위 질의가 한 행보다 많이 돌려줬습니다. LIMIT 1 이나 IN 을 써 보세요",
}
_CURSOR = re.compile(r"cannot open (\w+) query as cursor", re.I)
_QUOTED = re.compile(r'"([^"]+)"')


def _friendly(e: psycopg.Error) -> str:
    raw = e.diag.message_primary or str(e)
    if isinstance(e, psycopg.errors.RaiseException):
        return raw   # gov.run_agent_query 가 던진 한국어 안내는 그대로
    if m := _CURSOR.search(raw):
        return f"질의 작업대는 조회(SELECT)만 할 수 있습니다. {m.group(1).upper()} 문은 쓸 수 없습니다"
    tmpl = _FRIENDLY.get(e.sqlstate or "")
    if tmpl is None:
        return raw
    q = _QUOTED.search(raw)
    at = _QUOTED.search(raw.split("near", 1)[1]) if "near" in raw else None
    return tmpl.format(q=f" ({q.group(1)})" if q else "", at=f" ('{at.group(1)}' 근처)" if at else "")


class AgentQuery(BaseModel):
    sql: str = Field(min_length=1, max_length=20000)
    question: str | None = Field(default=None, max_length=1000)


@router.post("/query")
def agent_query(body: AgentQuery, s: Scoped = Depends(scoped)):
    """LLM 이 만든 SQL 을 lake_agent 로 실행한다. 읽기 전용 · 사용자 범위 · 단일 SELECT 만 (gov.run_agent_query).

    거절·오류도 감사로그에 남긴다. 그래서 예외를 다시 던지지 않고 응답으로 돌려준다 (던지면 감사 기록도 되돌려진다).
    """
    try:
        with agent_transaction(s.user) as ac:
            rows = ac.execute("SELECT gov.run_agent_query(%s, %s) AS rows",
                              (body.sql, settings.agent_row_limit)).fetchone()["rows"]
    except psycopg.Error as e:
        denied = isinstance(e, _DENIED)
        audit(s.conn, "query", None, channel="API", query_text=body.sql, result="DENIED" if denied else "ERROR")
        raw = e.diag.message_primary or str(e)
        return JSONResponse(status_code=403 if denied else 400, content={"detail": _friendly(e), "raw": raw})
    audit(s.conn, "query", None, channel="API", query_text=body.sql, row_count=len(rows))
    return {"rows": rows, "row_count": len(rows), "truncated": len(rows) >= settings.agent_row_limit}
