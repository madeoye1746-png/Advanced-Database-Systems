#!/bin/bash
# Usage: ./run_sql.sh <file.sql> [container] [db]
# Runs a SQL file inside the PostgreSQL container through a pseudo-terminal so that
# normal output and error messages appear in the correct order in the evidence files.
export MSYS_NO_PATHCONV=1
F="$1"; C="${2:-nm-primary}"; DB="${3:-naijamart}"
docker cp "$F" "$C:/tmp/run_$$.sql" >/dev/null
docker exec "$C" script -qec "psql -P pager=off -U postgres -d $DB -f /tmp/run_$$.sql" /dev/null | tr -d '\r'
