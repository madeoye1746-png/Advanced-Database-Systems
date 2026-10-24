\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'READER (REPEATABLE READ) first read: stock = ' || stock_qty AS reader FROM product WHERE product_id = 1;
SELECT pg_sleep(3) \gset
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'READER (REPEATABLE READ) second read: stock = ' || stock_qty AS reader FROM product WHERE product_id = 1;
COMMIT;
