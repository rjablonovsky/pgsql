#!/bin/sh

# ER diagrams for the pg13-oltp-test.corp.gljpc.com, pg13-ware-test.aws.gljpc.com, pg13-oltp-prod.corp.gljpc.com, pg13-ware-prod.aws.gljpc.com, pg13-sde-prod.corp.gljpc.com,  pg_production.corp.gljpc.com
DBUSER=postgres;
DBPASS="$(grep -e postgres .pgpass | awk -F: '{print $5}' | head -n 1)";
BINDIR=/mnt/c/work/bin; DOCDIR=/mnt/c/work/pgsql/doc;
SCHEMATA_SQL="select array_to_string(array_agg(schema_name), ',') from (select schema_name::text from information_schema.schemata where schema_name not like 'pg|_%' escape '|' and schema_name not in  ('information_schema','postgres','ihsdata') order by schema_name) a";

call_schemaspy_pgsql11 () {
  java -jar ${BINDIR}/schemaspy.jar -t pgsql11 -dp ${BINDIR}/jdbc/postgresql-42.3.1.jar -db ${DBNAME} -schemas "${SCHEMATA}" -host ${SERVER} -port 5432 -u ${DBUSER} -p "${DBPASS}" -o ${DOCDIR}/${SERVER}
}

call_schemaspy_pgsql () {
          java -jar ${BINDIR}/schemaspy.jar -t pgsql -dp ${BINDIR}/jdbc/postgresql-42.3.1.jar -db ${DBNAME} -schemas "${SCHEMATA}" -host ${SERVER} -port 5432 -u ${DBUSER} -p "${DBPASS}" -o ${DOCDIR}/${SERVER}
}

# postgresql server, db and schemata:
SERVER=pg13-oltp-test.corp.gljpc.com; DBNAME=pg13oltptest; SCHEMATA=$(psql -X -A -w -t -h ${SERVER} -d ${DBNAME} -U ${DBUSER} -c "${SCHEMATA_SQL}"); call_schemaspy_pgsql11;
#SERVER=pg13-ware-test.aws.gljpc.com;  DBNAME=pg13waretest; SCHEMATA=$(psql -X -A -w -t -h ${SERVER} -d ${DBNAME} -U ${DBUSER} -c "${SCHEMATA_SQL}"); call_schemaspy_pgsql11;
SERVER=pg13-oltp-prod.corp.gljpc.com; DBNAME=pg13oltpprod; SCHEMATA=$(psql -X -A -w -t -h ${SERVER} -d ${DBNAME} -U ${DBUSER} -c "${SCHEMATA_SQL}"); call_schemaspy_pgsql11;
SERVER=pg13-ware-prod.aws.gljpc.com;  DBNAME=pg13wareprod; SCHEMATA=$(psql -X -A -w -t -h ${SERVER} -d ${DBNAME} -U ${DBUSER} -c "${SCHEMATA_SQL}"); call_schemaspy_pgsql11;
SERVER=pg12-sde-prod.corp.gljpc.com;  DBNAME=pgsdeprod;    SCHEMATA=$(psql -X -A -w -t -h ${SERVER} -d ${DBNAME} -U ${DBUSER} -c "${SCHEMATA_SQL}"); call_schemaspy_pgsql11;
SERVER=Pg-Production.corp.gljpc.com;  DBNAME=pgprod;       SCHEMATA=$(psql -X -A -w -t -h ${SERVER} -d ${DBNAME} -U ${DBUSER} -c "${SCHEMATA_SQL}"); call_schemaspy_pgsql;
