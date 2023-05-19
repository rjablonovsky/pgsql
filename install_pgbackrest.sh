# source: https://pgbackrest.org/user-guide.htm

mkdir -p src/pgbackrest; cd src/pgbackrest;
wget https://github.com/pgbackrest/pgbackrest/archive/release/2.36.tar.gz .
tar -zxvf 2.36.tar.gz
sudo apt-get install make gcc libpq-dev libssl-dev libxml2-dev pkg-config \
       liblz4-dev libzstd-dev libbz2-dev libz-dev libyaml-dev
cd pgbackrest-release-2.36/src && ./configure && make

# install libraries, postgresql-client should be already installed:
sudo apt-get install libxml2
	   
# installation of the pgbackrest on production server
# libxml2 was already installed on the pg13-ware-prod for postgresql 13:
# sudo apt-get install postgresql-client libxml2
#pg-primary ⇒ Copy pgBackRest binary from build host from pg13-ware-test
sudo cp $HOME/src/pgbackrest/pgbackrest-release-2.36/src/pgbackrest /usr/bin/pgbackrest
# OR:
sudo cp /tmp/pgbackrest /usr/bin/pgbackrest
sudo chmod 755 /usr/bin/pgbackrest

#pgBackRest requires log, configuration directories and a configuration file.
#pg-primary ⇒ Create pgBackRest configuration file and directories
sudo mkdir -p -m 770 /var/log/pgbackrest
sudo chown postgres:postgres /var/log/pgbackrest
sudo mkdir -p /etc/pgbackrest
sudo mkdir -p /etc/pgbackrest/conf.d
sudo touch /etc/pgbackrest/pgbackrest.conf
sudo chmod 640 /etc/pgbackrest/pgbackrest.conf
sudo chown postgres:postgres /etc/pgbackrest/pgbackrest.conf

# on pg13-ware-prod.aws.gljpc.com
cat <<'EOF' > /etc/pgbackrest/pgbackrest.conf
[pg13wareprod]
pg1-path=/pg/cluster

[global]
repo1-cipher-pass=aYygYFuG5yKfkc_W9eu7h_tbyfFiUTjP8L7000IMq1p3vm9Gr_5mo0JZ4t562679
repo1-cipher-type=aes-256-cbc
repo1-path=/pg
repo1-retention-full=2

[global:archive-push]
compress-level=3

EOF

# on pg13-oltp-test.corp.gljpc.com
cat <<'EOF' > /etc/pgbackrest/pgbackrest.conf
[pg13oltptest]
pg1-path=/pg/cluster

[global]
repo1-cipher-pass=ghsfreYFuG5yKfkc_yhHu7h_tbyfFiUTjP8L70IMq1p3vm9Gr_5Jo0JZ4t672411
repo1-cipher-type=aes-256-cbc
repo1-path=/pg
repo1-retention-full=2

[global:archive-push]
compress-level=3

EOF

# modifications done to the postgresql.conf file:
# grep -e archive -e log_line -e max_wal_sender -e wal_level /pg/cluster/postgresql.conf
wal_level = replica                     # minimal, replica, or logical
archive_mode = on               # enables archiving; off, on, or always
#archive_command = 'pgbackrest --stanza=pg13wareprod archive-push %p'
archive_command = 'pgbackrest --stanza=pg13oltptest archive-push %p'
#archive_command = 'test ! -f /pg/archive/%f && gzip < %p > /pg/archive/%f' # command to use to archive a logfile segment
                                # placeholders: %p = path of file to archive
                                # e.g. 'test ! -f /mnt/server/archivedir/%f && cp %p /mnt/server/archivedir/%f'
archive_timeout = 300           # force a logfile segment switch after this
#restore_command = 'pgbackrest --stanza=pg13wareprod archive-get %f "%p"'
restore_command = 'pgbackrest --stanza=pg13oltptest archive-get %f "%p"'
#restore_command = 'test ! -f /pg/archive/%f && gunzip < /pg/archive/%f > %p'
                                # command to use to restore an archived logfile segment
                                # e.g. 'cp /mnt/server/archivedir/%f %p'
#archive_cleanup_command = ''   # command to execute at every restartpoint
#max_wal_senders = 10           # max number of walsender processes
#max_standby_archive_delay = 30s        # max delay before canceling queries
                                        # when reading WAL from archive;
log_line_prefix = '%m [%p] '            # special values:

### as of 2021-10-15 not done. REQUIRE approval and scheduled server restart.
sudo su - postgres
#mkdir -p /pg/archive/pg13wareprod/13-1
mkdir -p /pg/archive/pg13oltptest/13-1
#chmod -R 750 /pg/archive/pg13wareprod
chmod -R 750 /pg/archive/pg13oltptest
#chown -R postgres:dba /pg/archive/pg13wareprod
chown -R postgres:dba /pg/archive/pg13oltptest

# create stanza after restart of postgresql server:
#pgbackrest --stanza=pg13wareprod --log-level-console=info stanza-create
pgbackrest --stanza=pg13oltptest --log-level-console=info stanza-create
# check the configuration:
#pgbackrest --stanza=pg13wareprod --log-level-console=info check
pgbackrest --stanza=pg13oltptest --log-level-console=info check
# After pgbackrest info check, the postgresql crontab have to be modified from:
1 6 * * * find /pg/archive -type f -mtime +7 -exec /bin/rm -f {} \;
# TO:
#1 6 * * 0 find /pg/archive/pg13wareprod/13-1 -type f -mtime +7 -exec /bin/rm -f {} \;
1 6 * * 0 find /pg/archive/pg13oltptest/13-1 -type f -mtime +7 -exec /bin/rm -f {} \;
