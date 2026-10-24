\pset tuples_only on
\pset format unaligned
\pset fieldsep ' | '
SELECT to_char(clock_timestamp(),'HH24:MI:SS.MS') AS time, 'WRITER sets stock = 5 and commits' AS writer;
UPDATE product SET stock_qty = 5 WHERE product_id = 1;
