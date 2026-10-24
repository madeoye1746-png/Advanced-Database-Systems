\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 1;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A locked product 1' AS session_A;
SELECT pg_sleep(2) \gset
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A now wants product 2' AS session_A;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 2;
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A committed' AS session_A;
