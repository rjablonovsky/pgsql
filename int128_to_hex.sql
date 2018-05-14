
CREATE OR REPLACE FUNCTION int128_to_hex(decimal) RETURNS VARCHAR(32)
AS $$ 
/*
Function will converrt 128 bit integer represented/stored as decimal to hexadecimals with leading 0. 
Result is 32 character long.
*/
select 	lpad(to_hex(((floor(floor(floor($1/(256::decimal^4))/(256::decimal^4))/(256::decimal^4)))%(256::decimal^4))::bigint),8,'0') ||
	lpad(to_hex(((floor(floor($1/(256::decimal^4))/(256::decimal^4)))%(256::decimal^4))::bigint),8,'0') ||
	lpad(to_hex(((floor($1/(256::decimal^4)))%(256::decimal^4))::bigint),8,'0') ||
	lpad(to_hex(($1%(256::decimal^4))::bigint),8,'0')
;
$$ LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

/*
Tested on postgresql 10
-- tests:
select int128_to_hex(floor(256::decimal^16)) as test, '00000000000000000000000000000000' as isequal;
select int128_to_hex(floor(256::decimal^16)-127) as test, 'ffffffffffffffffffffffffffffff81' as isequal;
select int128_to_hex(floor(256::decimal^16)-floor(256::decimal^8)) as test, 'ffffffffffffffff0000000000000000' as isequal;
select int128_to_hex(floor(256::decimal^16)-floor(16*256::decimal^15)) as test, 'f0000000000000000000000000000000' as isequal;
-- check set/table output
SELECT int128_to_hex(id) as test, lpad(to_hex(id),32,'0') as isequal from generate_series(4499958769800000001,4499958769800000065,1) AS id;
SELECT int128_to_hex(id) as test, 'f'||lpad(to_hex((id-(floor(256::decimal^16)-floor(16*256::decimal^15)))::bigint),31,'0') as isequal
FROM generate_series(floor(256::decimal^16)-floor(16*256::decimal^15),floor(256::decimal^16)-floor(16*256::decimal^15)+65,1) AS id;
*/