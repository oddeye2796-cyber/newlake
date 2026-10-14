-- 외부 시연 DB(Neon 등)용 접속 계정. dev_roles.sql 과 같지만 비밀번호를 밖에서 받는다.
-- 사용: psql -v app_pw=… -v agent_pw=… -f db/seed/demo_roles.sql
SELECT format('CREATE ROLE svc_app LOGIN PASSWORD %L IN ROLE lake_app', :'app_pw')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_app') \gexec
SELECT format('CREATE ROLE svc_agent LOGIN PASSWORD %L IN ROLE lake_agent', :'agent_pw')
 WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'svc_agent') \gexec
SELECT format('ALTER ROLE svc_app PASSWORD %L', :'app_pw') \gexec
SELECT format('ALTER ROLE svc_agent PASSWORD %L', :'agent_pw') \gexec
ALTER ROLE svc_app SET timezone = 'Asia/Seoul';
ALTER ROLE svc_agent SET timezone = 'Asia/Seoul';
