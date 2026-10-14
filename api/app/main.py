from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .config import settings
from .db import app_pool, close_pools, open_pools
from .routers import admin, agent, core, entities, govadmin, inbox, ingest, kpi


@asynccontextmanager
async def lifespan(_: FastAPI):
    open_pools()
    yield
    close_pools()


app = FastAPI(title="newlake API", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["*"], allow_headers=["*"])

for r in (core.router, entities.router, kpi.router, inbox.router, agent.router, admin.router, ingest.router, govadmin.router):
    app.include_router(r)


@app.get("/api/health")
def health():
    with app_pool().connection() as conn:
        conn.execute("SELECT 1")
    return {"ok": True}


# DB 함수가 RAISE EXCEPTION 으로 거절한 것(권한 없음, 이미 처리됨, 다중문 등)은 사용자에게 그 문구로 돌려준다
@app.exception_handler(psycopg.errors.RaiseException)
async def raise_exception_handler(_: Request, exc: psycopg.errors.RaiseException):
    return JSONResponse(status_code=409, content={"detail": exc.diag.message_primary})


@app.exception_handler(psycopg.errors.InsufficientPrivilege)
async def privilege_handler(_: Request, exc: psycopg.errors.InsufficientPrivilege):
    return JSONResponse(status_code=403, content={"detail": exc.diag.message_primary})


@app.exception_handler(psycopg.errors.ReadOnlySqlTransaction)
async def readonly_handler(_: Request, exc: psycopg.errors.ReadOnlySqlTransaction):
    return JSONResponse(status_code=403, content={"detail": exc.diag.message_primary})


@app.exception_handler(psycopg.errors.SyntaxError)
async def syntax_handler(_: Request, exc: psycopg.errors.SyntaxError):
    return JSONResponse(status_code=400, content={"detail": exc.diag.message_primary})
