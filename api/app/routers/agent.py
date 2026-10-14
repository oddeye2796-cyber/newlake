import psycopg
from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from ..config import settings
from ..db import agent_transaction, audit
from ..deps import Scoped, scoped

router = APIRouter(prefix="/api/agent", tags=["agent"])

_DENIED = (psycopg.errors.RaiseException, psycopg.errors.InsufficientPrivilege, psycopg.errors.ReadOnlySqlTransaction)


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
        msg = e.diag.message_primary or str(e)
        return JSONResponse(status_code=403 if denied else 400, content={"detail": msg})
    audit(s.conn, "query", None, channel="API", query_text=body.sql, row_count=len(rows))
    return {"rows": rows, "row_count": len(rows), "truncated": len(rows) >= settings.agent_row_limit}
