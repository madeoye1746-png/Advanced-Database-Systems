\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B starts atomic UPDATE (will WAIT for A''s lock)' AS session_B;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 1;
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B committed (after waiting)' AS session_B;
