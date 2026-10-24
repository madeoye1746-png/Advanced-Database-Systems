\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
BEGIN ISOLATION LEVEL READ UNCOMMITTED;
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'READER (READ UNCOMMITTED) sees stock = ' || stock_qty AS reader FROM product WHERE product_id = 1;
COMMIT;
