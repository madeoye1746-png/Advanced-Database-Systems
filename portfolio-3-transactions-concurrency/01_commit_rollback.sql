-- =====================================================================
-- Portfolio 3 - 01_commit_rollback.sql
-- ACID in practice: COMMIT, ROLLBACK, SAVEPOINT and a safe stored function
-- Products 5 and 6 are used as test items (stock reset to 100).
-- =====================================================================
UPDATE product SET stock_qty = 100 WHERE product_id IN (5, 6);
SELECT 'STATE BEFORE' AS section,
       (SELECT count(*) FROM orders) AS orders,
       (SELECT stock_qty FROM product WHERE product_id = 5) AS stock_p5,
       (SELECT stock_qty FROM product WHERE product_id = 6) AS stock_p6;

-- ---------------------------------------------------------------------
SELECT '1. SUCCESSFUL ORDER - all steps COMMIT together (Atomicity + Durability)' AS section;
BEGIN;
INSERT INTO orders(customer_id, status) VALUES (1, 'PENDING') RETURNING order_id \gset
INSERT INTO order_item(order_id, product_id, quantity, unit_price)
       SELECT :order_id, 5, 3, unit_price FROM product WHERE product_id = 5;
UPDATE product SET stock_qty = stock_qty - 3 WHERE product_id = 5;
UPDATE orders SET total_amount = (SELECT SUM(quantity*unit_price) FROM order_item WHERE order_id = :order_id)
       WHERE order_id = :order_id;
COMMIT;
SELECT o.order_id, o.status, o.total_amount, oi.product_id, oi.quantity,
       (SELECT stock_qty FROM product WHERE product_id = 5) AS stock_p5_now
FROM orders o JOIN order_item oi USING (order_id) WHERE o.order_id = :order_id;

-- ---------------------------------------------------------------------
SELECT '2. FAILED ORDER - customer wants 500 units but only 97 exist: the ENTIRE transaction is rolled back' AS section;
SELECT count(*) AS orders_before FROM orders \gset
BEGIN;
INSERT INTO orders(customer_id, status) VALUES (2, 'PENDING') RETURNING order_id \gset
INSERT INTO order_item(order_id, product_id, quantity, unit_price)
       SELECT :order_id, 5, 500, unit_price FROM product WHERE product_id = 5;
UPDATE product SET stock_qty = stock_qty - 500 WHERE product_id = 5;   -- violates CHECK (stock_qty >= 0)
COMMIT;      -- a failed transaction cannot commit: PostgreSQL turns this into a ROLLBACK
SELECT 'AFTER FAILED ORDER' AS section,
       count(*) - :orders_before AS new_orders_left_behind,
       (SELECT count(*) FROM order_item WHERE order_id = :order_id) AS orphan_lines,
       (SELECT stock_qty FROM product WHERE product_id = 5) AS stock_p5_unchanged
FROM orders;

-- ---------------------------------------------------------------------
SELECT '3. SAVEPOINT - customer removes ONE item, but keeps the order' AS section;
BEGIN;
INSERT INTO orders(customer_id, status) VALUES (3, 'PENDING') RETURNING order_id \gset
INSERT INTO order_item(order_id, product_id, quantity, unit_price)
       SELECT :order_id, 5, 1, unit_price FROM product WHERE product_id = 5;
SAVEPOINT before_item_6;
INSERT INTO order_item(order_id, product_id, quantity, unit_price)
       SELECT :order_id, 6, 2, unit_price FROM product WHERE product_id = 6;
ROLLBACK TO SAVEPOINT before_item_6;          -- undo ONLY the second item
COMMIT;
SELECT order_id, product_id, quantity FROM order_item WHERE order_id = :order_id;

-- ---------------------------------------------------------------------
SELECT '4. EXPLICIT ROLLBACK - customer abandons checkout' AS section;
BEGIN;
INSERT INTO orders(customer_id, status) VALUES (4, 'PENDING') RETURNING order_id \gset
SELECT count(*) AS visible_inside_transaction FROM orders WHERE order_id = :order_id;
ROLLBACK;
SELECT count(*) AS visible_after_rollback FROM orders WHERE order_id = :order_id;
