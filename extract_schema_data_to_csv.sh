# run: sudo su - postgres
# screen
# psql -c '\timing' --echo-all -f extract-pg13waretest-combined_well-to_csv.sql -U postgres -d pg13waretest > extract-pg13waretest-combined_well-to_csv.log 2>&1
# ./extract_schema.sh

SCRIPT_FILE="$(realpath $0)"
SCRIPT_PATH="$(dirname ${SCRIPT_FILE})"
TIMESTAMP='date +%Y%m%d_%H%M%S.%N'

DB_SCHEMA="${1:-combined_well}"
CSV_PATH="${2:-/pg/s3nfs/pg13-ware-test/loader}"
DB_NAME="${3:-pg13waretest}"
DB_USER="${4:-postgres}"
DB_HOST="${5:-}"
if [[ ! -z "${DB_HOST// /}" ]]; then DB_HOST="-h ${DB_HOST}"; fi 

SQLFILE=${SCRIPT_PATH}/extract-${DB_NAME}-${DB_SCHEMA}-to_csv.sql
LOG="${SQLFILE}.log"

echo "$($TIMESTAMP), START generate extract schema SQL: $SCRIPT_FILE" | tee -a ${LOG}
cat <<EOF | psql -X -A -w -t -U "${DB_USER}" -d "${DB_NAME}" ${DB_HOST} > "${SQLFILE}" 2>${LOG}
select 
  case when relkind in ('r') then
    'COPY '||nspname||'.'||relname||' TO ''${CSV_PATH}/'||nspname||'.'||relname||'.csv'' DELIMITER '','' CSV;' 
  when relkind in ('m','v','f') then
    'COPY (SELECT * FROM '||nspname||'.'||relname||') TO ''${CSV_PATH}/'||nspname||'.'||relname||'.csv'' DELIMITER '','' CSV;'
  end as sql_cmd
       -- nspname, relname, relkind 
from pg_class c join pg_namespace n on c.relnamespace = n.oid 
where nspname = '${DB_SCHEMA}' and relkind in ('r','m','v','f') 
order by relkind, relname;
EOF

echo "$($TIMESTAMP), START extract schema: $SCRIPT_FILE" | tee -a ${LOG}
psql -c '\timing' --echo-all -f "${SQLFILE}" -U postgres -d pg13waretest >> "${LOG}" 2>&1
echo "$($TIMESTAMP), END extract schema: $SCRIPT_FILE" | tee -a ${LOG}
# get first 10 error messages from the log
ERROR_MSG="$(grep -A 2 -B 2 -i -e error -e fail ${LOG} | head)"
if [[ ! -z "${ERROR_MSG// /}" ]]; then echo "ERROR: ${ERROR_MSG}"; echo "LOG: $(hostname -f):${LOG} "; fi

