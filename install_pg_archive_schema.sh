cat<<'EOF_FILE' | sudo tee /usr/local/bin/pg_archive_schema
#!/bin/bash
#
# Script: /usr/local/bin/pg_archive_schema
#
#   Desc: This script backs up the schema(ta) in database on local server and store it/them in remote location
#   Require: gcloud auth activate-service-account --key-file <json file>; gsutil - compiled crcmod: True; 
#   Recommended: on OVH, GCP pgsql server have backup dir like /scratch/backup with read access by all OS users
# Author: Radovan Jablonovsky, Date: 2023-05-17
# Modified: Radovan Jablonovsky, Date: 2023-05-18, Parse backup log for error
#
# Example: pg_archive_schema "select 'archived_chain_skale_block_brawlers'";
#          pg_archive_schema "select 'chain_energi_testnet'" "/tmp";
#
#set -x # debuging

SCHEMATA_SQL="${1:-select array_to_string(array_agg(schema_name), ' ') from (select nspname as schema_name from pg_namespace where nspname ilike 'archived\_%' order by nspname) a}";
BACKUP_ROOT="${2:-/scratch/backup}"
GCP_BUCKET_ROOT="${3:-gs://covalenthq-blockdb-archived-chains}"

TIMESTAMP='date +%Y%m%d_%H%M%S.%N'
HOSTNAME=$(uname -n)
SCRIPT_FILE="$(realpath $0)"
SCRIPT_PATH="$(dirname ${SCRIPT_FILE})"
SCRIPT_BASENAME="$(basename ${SCRIPT_FILE})"
CMD="${0}"; for arg in "${@}"; do CMD="${CMD} \"${arg}\""; done
CURRENT_TIMESTAMP=$(date +%Y%m%d%H%M%S%N)
CURRENT_USER="$(id -u -n)"
CURRENT_USER_HOME=$(eval echo "~${CURRENT_USER}")
LOG="/var/log/postgresql/${SCRIPT_BASENAME}.log"

SCHEMATA=($(sudo -u postgres psql -X -A -w -t -d blockchains -c "${SCHEMATA_SQL}")) # SCHEMATA array
echo "${CURRENT_TIMESTAMP}, $($TIMESTAMP), START=${CMD}" | sudo -u postgres tee -a "${LOG}"
for SCHEMA in ${SCHEMATA[@]}; do
  SCHEMA_BAK="${SCHEMA}.pgdump.d"
  SCHEMA_BAK_DIR="${BACKUP_ROOT}/${SCHEMA_BAK}"
  GCP_BUCKET="${GCP_BUCKET_ROOT}/${SCHEMA_BAK}"
  
  # pg_dump with no compression
  #sudo -u postgres pg_dump --format=d --jobs=8 --compress=0 --username=postgres --dbname=blockchains --schema=${SCHEMA} -f "${SCHEMA_BAK_DIR}" 2>&1 | sudo -u postgres tee -a "${LOG}"
  # pg_dump with compression level 1 - looks like compress data 3-5 times better compared to no compression and data size is 10-20% bigger compared to level 6. The speed is comparable to pigz
  sudo -u postgres pg_dump --format=d --jobs=8 --compress=1 --username=postgres --dbname=blockchains --schema=${SCHEMA} -f "${SCHEMA_BAK_DIR}" 2>&1 | sudo -u postgres tee -a "${LOG}"
  echo "${CURRENT_TIMESTAMP}, $($TIMESTAMP), END backup of schema ${SCHEMA}, DISK_SIZE=$(sudo du -hs ${SCHEMA_BAK_DIR} | awk '{print $1}')" | sudo -u postgres tee -a "${LOG}"
  sudo chmod 755 "${SCHEMA_BAK_DIR}" 2>&1 | sudo -u postgres tee -a "${LOG}" # change mode of local backup folder
  # will create dir, all subdirectories and rsync files. gsutil output is stderr, do some tricks to filter stderr
  gsutil -o GSUtil:parallel_composite_upload_threshold=300M -m rsync -r "${SCHEMA_BAK_DIR}" "${GCP_BUCKET}" 2> >( sed -e '/\% Done/d' -e '/\r/d' | sudo -u postgres tee -a "${LOG}" >&1)
  echo "${CURRENT_TIMESTAMP}, $($TIMESTAMP), END rsync dir ${SCHEMA_BAK_DIR} to ${GCP_BUCKET}" | sudo -u postgres tee -a "${LOG}"
  sudo -u postgres rm -rf "${SCHEMA_BAK_DIR}" 2>&1 | sudo -u postgres tee -a "${LOG}"
  echo "${CURRENT_TIMESTAMP}, $($TIMESTAMP), END remove dir ${SCHEMA_BAK_DIR}" | sudo -u postgres tee -a "${LOG}"
done
echo "${CURRENT_TIMESTAMP}, $($TIMESTAMP), END=${CMD}" | sudo -u postgres tee -a "${LOG}"
# 2023-05-19 finish in morning !!!
# get first 10 error messages about current run from the log
ERROR_MSG="$(sed -n '/${CURRENT_TIMESTAMP}.*START=/,/${CURRENT_TIMESTAMP}.*END=/p' ${LOG} | grep -A 2 -B 2 -i -wE 'error|fail|fatal' | head)"
if [[ ! -z "${ERROR_MSG// /}" ]]; then echo "ERROR: ${ERROR_MSG}"; fi
EOF_FILE
sudo chmod 755 /usr/local/bin/pg_archive_schema