\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 2;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B locked product 2' AS session_B;
SELECT pg_sleep(2) \gset
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B now wants product 1' AS session_B;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 1;
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B script finished (if the deadlock victim: its transaction was rolled back)' AS session_B;
