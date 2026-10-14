import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """환경변수(LAKE_*)로 바꾼다. 기본값은 docker compose 개발 환경 기준."""

    model_config = SettingsConfigDict(env_prefix="LAKE_")

    # 일반 요청: svc_app (lake_app 멤버, RLS 적용)
    database_url: str = "postgresql://svc_app:svc_app_dev@localhost:5432/lake"
    # LLM SQL 실행: svc_agent (lake_agent 만)
    agent_database_url: str = "postgresql://svc_agent:svc_agent_dev@localhost:5432/lake"
    # 개발 인증: X-User-Id 헤더를 그대로 믿는다. 운영에서는 IdP(OIDC) 토큰 검증으로 바꾼다.
    dev_auth: bool = True
    dev_default_user: str = "u-jung"
    cors_origins: list[str] = ["http://localhost:5173"]
    # 서버리스(Vercel)는 인스턴스가 여러 개 뜨므로 인스턴스마다 접속을 적게 연다
    pool_max: int = 2 if os.environ.get("VERCEL") else 10
    agent_row_limit: int = 200


settings = Settings()
