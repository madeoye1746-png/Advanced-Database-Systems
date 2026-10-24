\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B asks for the row lock...' AS session_B;
SELECT stock_qty AS s FROM product WHERE product_id = 1 FOR UPDATE \gset
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B got the lock, read stock = ' || :s AS session_B;
UPDATE product SET stock_qty = :s - 1 WHERE product_id = 1;
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'B committed: wrote ' || (:s - 1) AS session_B;
