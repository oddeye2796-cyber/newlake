-- 개발용 접속 계정. 운영에서는 비밀번호를 비밀 저장소에서 넣고 이 파일은 쓰지 않는다.
-- 서버(일반 요청): svc_app  — lake_app 멤버, RLS 적용
-- 서버(LLM SQL):   svc_agent — lake_agent 만. lake_app 멤버로 만들지 않는다 (docs/schema_design.md 운영 메모)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_app') THEN
    CREATE ROLE svc_app LOGIN PASSWORD 'svc_app_dev' IN ROLE lake_app;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_agent') THEN
    CREATE ROLE svc_agent LOGIN PASSWORD 'svc_agent_dev' IN ROLE lake_agent;
  END IF;
END $$;
ALTER ROLE svc_app SET timezone = 'Asia/Seoul';
ALTER ROLE svc_agent SET timezone = 'Asia/Seoul';
