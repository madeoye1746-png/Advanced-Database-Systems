\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
-- Session A: classic read-modify-write done by the application (READ COMMITTED)
BEGIN;
SELECT stock_qty AS s FROM product WHERE product_id = 1 \gset
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A read stock = ' || :s AS session_A;
SELECT pg_sleep(2) \gset
UPDATE product SET stock_qty = :s - 1 WHERE product_id = 1;   -- writes a value computed from a STALE read
COMMIT;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'A committed: wrote ' || (:s - 1) AS session_A;
