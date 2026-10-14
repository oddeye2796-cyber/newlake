#!/usr/bin/env bash
# 개발 DB 한 번에 준비: 스키마 적용 → 접속 계정 → 개발 시드
# 사용: PGHOST=… PGPORT=… PGUSER=… bash db/init_dev.sh [dbname]
set -euo pipefail
DB=${1:-lake}
here="$(cd "$(dirname "$0")" && pwd)"
bash "$here/apply.sh" "$DB"
psql -d "$DB" -v ON_ERROR_STOP=1 -q -f "$here/seed/dev_roles.sql"
psql -d "$DB" -v ON_ERROR_STOP=1 -q -1 -f "$here/seed/dev_seed.sql"
echo "== 개발 시드 완료 ($DB)"
