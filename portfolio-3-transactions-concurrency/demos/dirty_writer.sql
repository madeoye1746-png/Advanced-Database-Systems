\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN;
UPDATE product SET stock_qty = 1 WHERE product_id = 1;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'WRITER changed stock to 1 but has NOT committed' AS writer;
SELECT pg_sleep(4) \gset
ROLLBACK;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'WRITER rolled back' AS writer;
