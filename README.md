# newlake — 온톨로지 기반 데이터레이크

KS X 9101-1:2025 제조 온톨로지를 따라가는 데이터레이크 플랫폼. 대상은 **온프레미스 PostgreSQL 16 + pgvector + TimescaleDB**.

## 폴더

| 폴더 | 내용 |
|---|---|
| `ontology/` | KS X 9101 코어 TTL, SHACL, 코드리스트, 기업 확장(arcon), 레이크 메타(lake) |
| `db/schema/` | 스키마 SQL (raw·ksx·sem·mart·onto·catalog·gov). `10`·`11`·`90` 은 생성 파일 |
| `db/apply.sh` | 빈 DB 또는 기존 DB 에 적용. 파일 단위 트랜잭션 + `gov.schema_migration` 기록 |
| `db/seed/`, `db/init_dev.sh` | 개발용 접속 계정(svc_app·svc_agent)과 시연 시드(사용자 5명, 리스크, 승인 대기, 파이프라인·품질·접근 요청) |
| `api/` | FastAPI 서버. 요청마다 사용자 범위를 SET LOCAL 하고 RLS 로 거른다 |
| `web/` | 화면 (React + Vite). 업무(홈·질문·찾기·KPI·승인함)와 데이터 관리(관리자용: 오늘의 레이크·데이터 넣기·카탈로그·온톨로지·계보·품질·작업대·권한/감사) |
| `tools/` | `gen_ontology.py`(테이블정의서 → TTL), `gen_schema.py`(TTL → DDL·시드) |
| `source_extracts/` | 테이블정의서·코드 정의서 추출본 (생성기 입력) |
| `docs/` | 온톨로지 설계, 스키마 설계(v0.5), 리뷰 기록 |

## 바로 띄우기

```bash
docker compose up --build
# 화면 http://localhost:5173   API 문서 http://localhost:8000/docs
```

DB(TimescaleDB+pgvector) → 스키마·시드 적용 → API → 화면 순서로 뜬다. 화면 오른쪽 위에서 사용자를 바꿀 수 있다.

| 사용자 | 역할 | 범위 | 용도 |
|---|---|---|---|
| u-jung 정품질 | 분석가 | HQ/P1 | 조회·제안. 승인은 거절된다 |
| u-kim 김품질 | 품질 엔지니어 | 회사 전체 | 로트 보류 승인자 |
| u-lee 이생산 | 생산관리자 | HQ/P1 | KPI |
| u-park 박이공 | 분석가 | HQ/P2 | 범위 밖 데이터가 안 보이는지 확인용 |
| u-choi 최관리 | 관리자·데이터 스튜어드 | 회사 전체 | 데이터 관리 화면, 접근 요청 승인 |

인증은 개발용으로 `X-User-Id` 헤더를 그대로 믿는다(`LAKE_DEV_AUTH=true`). 운영 전에 OIDC 토큰 검증으로 바꿔야 한다.

## 미리보기 (GitHub Pages)

`main` 에 `web/` 변경이 들어가면 `.github/workflows/pages.yml` 이 화면을 **시연 모드**(`VITE_DEMO=1`)로 빌드해 GitHub Pages 에 올린다. 시연 모드는 서버 없이 `web/src/demo/fixtures.json`(실제 API 응답을 녹화한 것)으로 동작하고, 승인·반려도 화면 안에서 흉내 낸다.

- 처음 한 번: 저장소 Settings → Pages → Source 를 **GitHub Actions** 로 둔다.
- 시드나 API 가 바뀌면 API 를 띄운 상태에서 `python3 tools/record_demo_fixtures.py` 로 다시 녹화한다.
- 화면은 다크(기본)·라이트 테마를 오른쪽 위 버튼으로 바꾼다.

## 실제 DB 시연 (Vercel + Neon)

https://newlake.vercel.app 은 화면과 API 를 Vercel 에 올리고 Neon(무료 PostgreSQL)의 시연 DB 를 쓴다. 운영 대상은 그대로 사내 PostgreSQL 이고, 이건 외부 시연용이다.

- `vercel.json`: `/api/*` 는 `api/index.py`(FastAPI 서버리스 함수), 나머지는 `web/` 빌드 결과로 보낸다.
- Vercel 환경변수: `LAKE_DATABASE_URL`(svc_app), `LAKE_AGENT_DATABASE_URL`(svc_agent). Neon 의 direct 연결 문자열을 쓴다.
- Neon 에 스키마를 다시 올릴 때는 Actions 의 `demo-db` 워크플로를 손으로 실행한다(Secret `NEON_DATABASE_URL`, `DEMO_SVC_PASSWORD`). Neon 의 TimescaleDB 는 연속 집계를 못 써서 `31_raw_timescale.sql` 은 건너뛴다.
- 인증은 개발용(`X-User-Id`)이라 주소를 아는 사람은 누구나 시연 사용자로 승인·반려를 해볼 수 있다. 시연 데이터만 넣는다.

## API 구조

- 요청 하나가 트랜잭션 하나다. `gov.user_context()` 로 사용자의 회사·사업장·공장을 받아 `app.*` 를 SET LOCAL 하고, RLS(`gov.scope_ok`)가 행을 거른다.
- 승인·반려는 `gov.decide_action()` 으로만 한다. 역할과 범위 판정은 DB 가 하고, 거절 사유는 409 로 그대로 돌려준다.
- LLM SQL 은 별도 접속 계정 `svc_agent` 로 `BEGIN READ ONLY → SET LOCAL app.* → SET LOCAL ROLE lake_agent → gov.run_agent_query()` 로만 실행한다. 거절도 감사로그에 남는다.
- 로트·설비 화면 조회는 `gov.audit_log` 에 남는다.
- `/api/admin/*` 는 admin·data_steward·data_engineer·ontology_manager 역할만 쓴다. 접근 요청 승인은 `gov.decide_access_request()` 로만 하고, 본인 요청은 본인이 승인할 수 없다.

## 데이터 넣기 (관리 화면)

데이터 관리 → **데이터 넣기**(`/admin/ingest`)에서 관리자·데이터 엔지니어·스튜어드가 데이터를 넣는다.

1. **원천 관리**: 원천 시스템을 등록한다(`catalog.source_system` + `catalog.source_connection`). 비밀번호는 저장하지 않는다. 운영에서는 `secret_ref` 에 비밀 저장소 이름을 둔다.
2. **파일 올리기**: CSV·TSV·엑셀(.xlsx)을 올리면 `raw.ingest_batch`·`raw.landing_record`·`raw.landing_file` 에 원본 그대로 남고, 데이터셋 `raw.<원천>.<엔터티>` 와 필드 목록이 카탈로그에 생긴다. 4MB·2만 행까지.
   **DB에서 가져오기**: PostgreSQL 원천에 읽기 전용으로 붙어 표를 고르고 최대 5,000행을 원천 존으로 가져온다. 다른 DB 는 등록만 되고, 파일로 내보내 올린다.
3. **열 맞추기**: 열 이름과 KS X 표준 열의 한글 설명을 비교해 넣을 표와 열 대응을 먼저 제안한다. 확인 후 **표준 존에 넣기**를 누르면 `gov.standardize_batch()` 가 행마다 upsert 하고, 타입 오류·참조 무결성 위반·범위 밖 행은 그 행만 거부한다. 매핑(`catalog.mapping`), 작업 기록(`catalog.job_run`), 계보(`catalog.lineage_edge`), 감사 기록이 함께 남는다.

쓰기는 모두 `gov.register_source`·`gov.ingest_records`·`gov.standardize_batch`(SECURITY DEFINER)로만 하고, 함수가 역할과 회사·사업장·공장 범위를 다시 확인한다. 공개 시연(Vercel)에서는 사내망·로컬 주소로 DB 연결을 못 하게 막는다(`LAKE_INGEST_ALLOW_PRIVATE_HOSTS`).

## 테스트

```bash
bash db/init_dev.sh lake            # 실제 PG 에 스키마+시드
cd api && pip install -r requirements-dev.txt
LAKE_DATABASE_URL=postgresql://svc_app:svc_app_dev@localhost:5432/lake \
LAKE_AGENT_DATABASE_URL=postgresql://svc_agent:svc_agent_dev@localhost:5432/lake pytest -q
```

CI(`.github/workflows/ci.yml`)는 TimescaleDB 이미지에 스키마를 올리고, 재실행이 모두 건너뛰는지, 하이퍼테이블이 생겼는지 확인한 뒤 API 테스트와 화면 빌드를 돌린다.

## DB 적용

```bash
# TimescaleDB·pgvector 가 설치된 PG16
PGHOST=… PGPORT=… PGUSER=… bash db/apply.sh lake
# 개발 PC 에 TimescaleDB 가 없으면 (운영 금지)
ALLOW_TS_FALLBACK=1 bash db/apply.sh lake
# 운영에는 예시 데이터 없이
SAMPLE=0 bash db/apply.sh lake
```

스키마를 바꿀 때는 기준선 파일을 고치지 말고 `db/schema/V0002__설명.sql` 처럼 새 파일을 추가한다. 이름순으로 적용된다.

표준이 개정되면 `python3 tools/gen_ontology.py && python3 tools/gen_schema.py` 로 TTL·DDL·시드를 다시 만든다(rdflib 필요).

설계와 운영 규약(범위 주입, 타임존, 접속 계정, 승인 함수)은 [`docs/schema_design.md`](docs/schema_design.md) 를 본다.
