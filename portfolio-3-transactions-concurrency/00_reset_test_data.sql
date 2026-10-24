-- Puts two test products in a known state before every demo
UPDATE product SET stock_qty = 10 WHERE product_id IN (1, 2);
TRUNCATE stock_audit RESTART IDENTITY;
