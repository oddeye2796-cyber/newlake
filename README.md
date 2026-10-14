# newlake — 온톨로지 기반 데이터레이크

KS X 9101-1:2025 제조 온톨로지를 따라가는 데이터레이크 플랫폼. 대상은 **온프레미스 PostgreSQL 16 + pgvector + TimescaleDB**.

## 폴더

| 폴더 | 내용 |
|---|---|
| `ontology/` | KS X 9101 코어 TTL, SHACL, 코드리스트, 기업 확장(arcon), 레이크 메타(lake) |
| `db/schema/` | 스키마 SQL (raw·ksx·sem·mart·onto·catalog·gov). `10`·`11`·`90` 은 생성 파일 |
| `db/apply.sh` | 빈 DB 또는 기존 DB 에 적용. 파일 단위 트랜잭션 + `gov.schema_migration` 기록 |
| `tools/` | `gen_ontology.py`(테이블정의서 → TTL), `gen_schema.py`(TTL → DDL·시드) |
| `source_extracts/` | 테이블정의서·코드 정의서 추출본 (생성기 입력) |
| `docs/` | 온톨로지 설계, 스키마 설계(v0.5), 리뷰 기록 |

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
