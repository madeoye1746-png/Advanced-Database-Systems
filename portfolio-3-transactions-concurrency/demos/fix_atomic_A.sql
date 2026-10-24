\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A starts atomic UPDATE' AS session_A;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 1;   -- computed inside the DB
SELECT pg_sleep(2) \gset
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A committed' AS session_A;
