#!/bin/bash
### Non-exclusive low level postgresql backup using filesystem snapshots
### with steps logging

## environment specific variables
NETAPP=ftxefs01.prod.mysystem.com
VSERVER=ftxefs01nfs
VOLUME=FCA_DD_HISTORICDB_UAT
HOSTNAME=$(hostname)

## common variables
TIMESTAMP=$(date +%Y%m%d%H%M%S)
CLONE="$VOLUME"_"$TIMESTAMP"
BACKUP_LABEL="$HOSTNAME"_"$CLONE"

LOG="${1:-/home/postgres/scripts/log/db_backup_ne_fs_snap_${TIMESTAMP}.log}"

#CREATECMD="exit"   # for ssh connection test
CREATECMD="volume clone create -vserver $VSERVER -flexclone $CLONE -parent-volume $VOLUME"

cat <<EOF | psql -U postgres -p 5432 -h 127.0.0.1 > "${LOG}" 2>&1
SELECT now() as pg_start_backup_BEGIN;
SELECT pg_start_backup('$BACKUP_LABEL', false, false);
SELECT now() as volume_clone_BEGIN;
\! ssh -i /home/postgres/.ssh/dbsnap.priv dbsnap@$NETAPP "$CREATECMD" 2>&1
SELECT now() as pg_stop_backup_BEGIN;
SELECT pg_stop_backup(false);
SELECT now() as pg_stop_backup_END;
EOF

