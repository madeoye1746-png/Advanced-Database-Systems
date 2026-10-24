\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
-- Session B: same logic, but fast
BEGIN;
SELECT stock_qty AS s FROM product WHERE product_id = 1 \gset
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B read stock = ' || :s AS session_B;
UPDATE product SET stock_qty = :s - 1 WHERE product_id = 1;
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B committed: wrote ' || (:s - 1) AS session_B;
