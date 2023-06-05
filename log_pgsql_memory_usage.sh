#!/bin/bash
#
# Get postgresql processes memory usage order byt RES
# RES: Resident memory: current amount of process memory that resides in physical memory
#* * * * * /home/postgres/log_pgsql_memory_usage.sh "/pg/cluster"
# OR
# * * * * * /home/postgres/log_pgsql_memory_usage.sh "/pg/db"
#
# needed by JIRA: http://jira.corp.gljpc.com:8080/browse/ITP-6635
#

HOME_DIR=/home/postgres
PG_TOP="/usr/bin/pg_top"

LOG_DIR="${1:-$PGDATA}"/$(psql -X -A -w -t -c "select setting from pg_settings where name = 'log_directory'")
UNIX_SOCKET_DIR="${2:-/$(psql -X -A -w -t -c "select setting from pg_settings where name = 'unix_socket_directories'")}"
PG_LOG_TEMPLATE="${LOG_DIR}/postgresql-*.csv"
LAST_PG_LOG=$(ls -t $PG_LOG_TEMPLATE | head -n 1)
PG_TOP_LOG="${LAST_PG_LOG%.csv}-pg_top.log"

# Add datetime and data to pg_top log file
date '+%Y-%m-%d %H:%M:%S.%N %Z:' >> "${PG_TOP_LOG}"
$PG_TOP --host="$UNIX_SOCKET_DIR" --order-field=res --batch >> "${PG_TOP_LOG}"

