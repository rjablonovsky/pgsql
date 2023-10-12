-- ###### EXAMPLE of STEPS
-- ### create as user postgres replication schema schtest, table and grant access to replication user: repl
-- set servername on postgresql db on server ubuntu2204-5433:
ALTER DATABASE appdata SET "app.settings.servername" TO 'ubuntu2204-5433';
ALTER DATABASE template1 SET "app.settings.servername" TO 'ubuntu2204-5433';
ALTER DATABASE postgres SET "app.settings.servername" TO 'ubuntu2204-5433';

SELECT current_setting('app.settings.servername', true) as servername;
SET ROLE postgres;

-- # create user reverse_etl_ch_pg with password encrypted by scram-sha-256: pass: <is in .pgpass_local file> pgsql_repl_12345test123
-- DROP ROLE IF EXISTS repl;
DO $$
DECLARE
  _role_name text := 'repl';
  _encrypted_pass text := 'SCRAM-SHA-256$4096:pRy1Hqdl8fOToHWSBdA55Q==$YeTBwl7B516Po1GTWZuHMfeEIlpzTxu8ReGPKld2elM=:oiN2krVFu8MykNy7e/0H9oSKEA8H4WtiiFWsn0n4qWY=';
BEGIN
  IF NOT EXISTS(select 1 from pg_authid where rolname = _role_name) THEN
    RAISE NOTICE 'CREATE ROLE % WITH LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE REPLICATION;', _role_name;
    EXECUTE FORMAT('CREATE ROLE %I WITH LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE REPLICATION ENCRYPTED PASSWORD %L;', _role_name, _encrypted_pass);
  ELSE
    RAISE NOTICE 'ALTER ROLE % WITH LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE REPLICATION;', _role_name;
    EXECUTE FORMAT('ALTER ROLE %I WITH LOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE REPLICATION ENCRYPTED PASSWORD %L;', _role_name, _encrypted_pass);  
  END IF;
END; $$;

CREATE SCHEMA IF NOT EXISTS schtest;
GRANT USAGE ON SCHEMA schtest to repl;

CREATE TABLE IF NOT EXISTS schtest.test
( test_id uuid NOT NULL,
  col1 text,
  CONSTRAINT test_pkey PRIMARY KEY (test_id)
);
GRANT ALL ON TABLE schtest.test TO repl;

-- CREATE publication app_schtest
-- DROP PUBLICATION IF EXISTS app_schtest;
CREATE PUBLICATION app_schtest
    FOR TABLE schtest.test
    WITH (publish = 'insert, update, delete, truncate', publish_via_partition_root = false);

-- on subscriber create .pgpass in user postgres home dir with connect to the publisher
-- DROP SUBSCRIPTION IF EXISTS app_schtest_ubuntu2204;
CREATE SUBSCRIPTION app_schtest_s1
  CONNECTION 'host=127.0.0.1 port=5433 user=repl dbname=appdata'
  PUBLICATION app_schtest
  WITH (connect = true, enabled = true, create_slot = false, slot_name = app_schtest_s1, synchronous_commit = 'off');

-- on publisher  create slot using db user repl: 
SELECT * FROM pg_create_logical_replication_slot('app_schtest_s1', 'pgoutput');  

--  insert some data to table on publisher
INSERT INTO schtest.test(test_id, col1) VALUES ('00000000-0000-0000-0000-000000000001'::uuid,'test1'),('00000000-0000-0000-0000-000000000002'::uuid,'test2');
-- get data on subscriber:
SELECT * FROM schtest.test limit 3;

-- ### MODIFICATION to table on publisher and subscriber(s):
/*
1) Stop if possible client/app doing insert/update/delete to table to be modified
2) If modification will affect the primary key or unique used  by logical replication to identify relicated data row in table, 
   or would like to refresh data from publication, remove table from publication. Refresh subscription(s) with copy_data=false 
   to propagate table removal from publisher to subscriber.
3) Disable subscriptions
4) Apply DDL modifications on publisher and sunsciber(s)
5) Enable subscription(s)
6) Check publisher, subscriber status
7) Add the modified table to the publication
8) Refresh subscription(s) with copy_data=false, if the modification does not require data be synchronized 
   or with copy_data=true, if data should be synchronized with publisher. In case of copy_data=true the data 
  in table on subscriber should be removed/trunacted to avoid conflict(s)
*/

-- 2) on publisher remove table from publication:
ALTER PUBLICATION app_schtest DROP TABLE schtest.test;
-- on sunscriber(s) refresh subscription to propagate table removal from publisher to subscriber
ALTER SUBSCRIPTION app_schtest_s1 REFRESH PUBLICATION WITH (copy_data=false);

-- 3) on subscriber9s) disable subscription:
ALTER SUBSCRIPTION app_schtest_s1 DISABLE;

-- 4) modification to table test: alter data type of colums, add columns, alter primary key
-- Have to be done on publisher and subscriber(s)
ALTER TABLE schtest.test ALTER COLUMN test_id TYPE bigint USING ('x' || substring(replace(test_id::text, '-', ''),17,16))::bit(64)::bigint;
ALTER TABLE IF EXISTS schtest.test
  ADD COLUMN asset_offset integer NOT NULL DEFAULT 0,
  ADD COLUMN scraped_on timestamp(0) with time zone NOT NULL DEFAULT 'now()';
ALTER TABLE schtest.test
  DROP CONSTRAINT test_pkey,
  ADD PRIMARY KEY(test_id, asset_offset);
  
-- 5) on subscriber(s):
ALTER SUBSCRIPTION app_schtest_s1 ENABLE;

-- 6) Check publisher, subsriber status
-- test on publisher: 
select * from pg_stat_replication;
select * from pg_stat_replication_slots;
-- test on subscriber(s):
select now(), * from pg_stat_subscription;
  
-- 7) on publisher:
ALTER PUBLICATION app_schtest
    ADD TABLE schtest.test;
     
-- 8) on subscriber refresh publication after adding table:
ALTER SUBSCRIPTION app_schtest_s1 REFRESH PUBLICATION WITH (copy_data=false);

-- test on publisher:
select * from pg_stat_replication;
select * from pg_stat_replication_slots;
select * from schtest.test limit 9;
insert into schtest.test(test_id, col1) values (21,'test1'),(22,'test2'),(23,'test3');

-- test on subscriber(s):
select now(), * from pg_stat_subscription;
select * from schtest.test limit 9;

