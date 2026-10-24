\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
-- Fix: every transaction locks rows in the SAME order (lowest product_id first)
BEGIN;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 1;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B locked product 1 (after waiting for A)' AS session_B;
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 2;
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B committed' AS session_B;
