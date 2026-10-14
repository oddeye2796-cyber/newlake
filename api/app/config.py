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
    # 데이터 넣기: 올리는 파일 크기·행 수 상한 (Vercel 요청 본문은 4.5MB 까지)
    ingest_max_bytes: int = 4 * 1024 * 1024
    ingest_max_rows: int = 20000
    # 원천 DB 연결 시험에서 사내망·로컬 주소 허용. 사내 설치는 허용, 공개 시연(Vercel)은 막는다 (SSRF)
    ingest_allow_private_hosts: bool = not os.environ.get("VERCEL")


settings = Settings()
