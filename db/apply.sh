#!/usr/bin/env bash
# 온프레미스/로컬 PostgreSQL 16 에 전체 스키마 + 예시 데이터를 적용한다.
# 사용: PGHOST=… PGPORT=… PGUSER=… bash db/apply.sh [dbname]
# 필요 확장: pgvector, timescaledb (shared_preload_libraries='timescaledb')
#   TimescaleDB 가 없으면 기본은 중단한다. 개발 PC 처럼 대체 경로(일 파티션)로 충분할 때만 ALLOW_TS_FALLBACK=1.
# 운영 DB 에는 SAMPLE=0 으로 예시 데이터를 빼고 적용할 것.
#
# 마이그레이션 (리뷰 F21):
#   · 파일마다 한 트랜잭션(psql -1). 중간에 실패하면 그 파일은 통째로 되돌려진다. (31 은 연속 집계 때문에 예외)
#   · 적용한 파일은 gov.schema_migration 에 sha256 과 함께 남고, 다시 실행하면 건너뛴다.
#   · 적용 후 파일이 바뀌었으면 경고만 하고 건너뛴다. 운영 변경은 V0002__*.sql 같은 새 파일로 추가한다.
#     지금 db/schema 의 파일들은 V0001 기준선이다. 정식 도구가 필요하면 sqitch·dbmate 로 옮겨도 같은 순서를 쓴다.
set -euo pipefail
DB=${1:-lake}
ALLOW_TS_FALLBACK=${ALLOW_TS_FALLBACK:-0}
SAMPLE=${SAMPLE:-1}
cd "$(dirname "$0")/schema"

# 데이터베이스가 없을 때만 만든다 (권한 오류 등은 그대로 실패시킨다 — 리뷰 F27)
if [ "$(psql -d postgres -tAc "select count(*) from pg_database where datname = '$DB'")" != "1" ]; then
  createdb "$DB"
fi

q(){ psql -d "$DB" -v ON_ERROR_STOP=1 -tAc "$1"; }
has_ts(){ [ "$(q "select count(*) from pg_extension where extname='timescaledb'")" = "1" ]; }

# run <file> [notx] — 적용 기록을 보고 새 파일만 한 트랜잭션으로 적용
run(){
  local f=$1 mode=${2:-tx} sum applied
  sum=$(sha256sum "$f" | cut -d' ' -f1)
  applied=$(q "select checksum from gov.schema_migration where version = '$f'" 2>/dev/null || true)
  if [ -n "$applied" ]; then
    if [ "$applied" = "$sum" ]; then echo "-- $f (이미 적용됨)"
    else echo "!! $f 는 적용 후 바뀌었습니다. 건너뜁니다 — 변경분은 새 마이그레이션 파일로 추가하세요." >&2; fi
    return 0
  fi
  echo "== $f"
  if [ "$mode" = "notx" ]; then
    psql -d "$DB" -v ON_ERROR_STOP=1 -q -f "$f"
    q "insert into gov.schema_migration (version, checksum) values ('$f', '$sum')" >/dev/null
  else
    { cat "$f"; echo; echo "INSERT INTO gov.schema_migration (version, checksum) VALUES ('$f', '$sum');"; } \
      | psql -d "$DB" -v ON_ERROR_STOP=1 -q -1
  fi
}

run 00_schemas.sql
if ! has_ts; then
  if [ "$ALLOW_TS_FALLBACK" = "1" ]; then
    echo "!! timescaledb 없음 — raw.ts_point 를 일 파티션 대체 경로로 만듭니다 (운영 금지)"
  else
    echo "!! timescaledb 확장이 없습니다. 설치·shared_preload_libraries 설정 후 다시 실행하거나, 개발용이면 ALLOW_TS_FALLBACK=1" >&2
    exit 1
  fi
fi
for f in 10_ksx_tables.sql 11_ksx_fk.sql 20_onto.sql 21_catalog.sql 30_raw.sql; do run "$f"; done
if has_ts; then run 31_raw_timescale.sql notx; fi
for f in 40_sem.sql 50_mart.sql 60_gov.sql 70_rls.sql 90_seed_ontology.sql 91_seed_actions.sql; do run "$f"; done
# 증분 마이그레이션 (V0002__*.sql …) — 이름순
for f in $(ls V[0-9]*__*.sql 2>/dev/null | sort); do run "$f"; done
if [ "$SAMPLE" = "1" ]; then run 95_sample_data.sql; fi

# RLS 누락 검사 (리뷰 F13) — 한 행이라도 있으면 실패
gaps=$(q "select string_agg(table_name || ' (' || problem || ')', ', ') from gov.rls_gaps()")
if [ -n "$gaps" ]; then echo "!! RLS 누락: $gaps" >&2; exit 1; fi
echo "== RLS 누락 0건"

# 적재 접속 계정 점검 (재검토 N4): BYPASSRLS 는 멤버십으로 상속되지 않는다
nobypass=$(q "select string_agg(m.rolname, ', ') from pg_auth_members am join pg_roles g on g.oid = am.roleid join pg_roles m on m.oid = am.member where g.rolname = 'lake_loader' and m.rolcanlogin and not m.rolbypassrls")
if [ -n "$nobypass" ]; then echo "!! lake_loader 멤버 접속 계정에 BYPASSRLS 가 없습니다: $nobypass — ALTER ROLE <계정> BYPASSRLS; 를 주거나 적재 세션마다 SET ROLE lake_loader" >&2; fi

# 역할별 스모크 테스트 (리뷰 F1: 소유자로만 검증하면 권한 누락이 안 잡힌다)
echo "== 역할별 스모크 테스트"
psql -d "$DB" -v ON_ERROR_STOP=1 -q <<'SQL'
BEGIN;
SET LOCAL ROLE lake_app;
SET LOCAL app.enterprise_id = 'ACME'; SET LOCAL app.site_ids = '*'; SET LOCAL app.plant_ids = '*'; SET LOCAL app.user_id = 'smoke';
INSERT INTO gov.audit_log (channel, action) VALUES ('UI', 'smoke-test');
SELECT count(*) AS lake_app_lots FROM ksx.lot;
ROLLBACK;
BEGIN;
SET LOCAL ROLE lake_loader;
INSERT INTO sem.named_graph (graph_iri, graph_kind, enterprise_id) VALUES ('urn:smoke', 'ABOX', 'ACME');
INSERT INTO sem.quad (graph_iri, s, p, o_literal, tier) VALUES ('urn:smoke', 'urn:s', 'urn:p', 'x', 'ASSERTED');
ROLLBACK;
SQL
if [ "$SAMPLE" = "1" ]; then
  psql -d "$DB" -c "select lot_id, defect_rate_pct, sales_order_id, risk_level from mart.v_otd_risk_candidate"
fi
echo "완료"
