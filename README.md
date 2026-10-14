# newlake — 온톨로지 기반 데이터레이크

KS X 9101-1:2025 제조 온톨로지를 따라가는 데이터레이크 플랫폼. 대상은 **온프레미스 PostgreSQL 16 + pgvector + TimescaleDB**.

## 폴더

| 폴더 | 내용 |
|---|---|
| `ontology/` | KS X 9101 코어 TTL, SHACL, 코드리스트, 기업 확장(arcon), 레이크 메타(lake) |
| `db/schema/` | 스키마 SQL (raw·ksx·sem·mart·onto·catalog·gov). `10`·`11`·`90` 은 생성 파일 |
| `db/apply.sh` | 빈 DB 또는 기존 DB 에 적용. 파일 단위 트랜잭션 + `gov.schema_migration` 기록 |
| `db/seed/`, `db/init_dev.sh` | 개발용 접속 계정(svc_app·svc_agent)과 시연 시드(사용자 4명, 리스크, 승인 대기) |
| `api/` | FastAPI 서버. 요청마다 사용자 범위를 SET LOCAL 하고 RLS 로 거른다 |
| `web/` | 엔드유저 화면 (React + Vite). 목업의 홈·질문·찾기·KPI·승인함 |
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

인증은 개발용으로 `X-User-Id` 헤더를 그대로 믿는다(`LAKE_DEV_AUTH=true`). 운영 전에 OIDC 토큰 검증으로 바꿔야 한다.

## API 구조

- 요청 하나가 트랜잭션 하나다. `gov.user_context()` 로 사용자의 회사·사업장·공장을 받아 `app.*` 를 SET LOCAL 하고, RLS(`gov.scope_ok`)가 행을 거른다.
- 승인·반려는 `gov.decide_action()` 으로만 한다. 역할과 범위 판정은 DB 가 하고, 거절 사유는 409 로 그대로 돌려준다.
- LLM SQL 은 별도 접속 계정 `svc_agent` 로 `BEGIN READ ONLY → SET LOCAL app.* → SET LOCAL ROLE lake_agent → gov.run_agent_query()` 로만 실행한다. 거절도 감사로그에 남는다.
- 로트·설비 화면 조회는 `gov.audit_log` 에 남는다.

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
