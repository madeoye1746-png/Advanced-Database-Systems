-- Portfolio 1 - 03_constraint_tests.sql
-- Proves that keys and constraints really protect the data.
-- Each statement below is EXPECTED TO FAIL (psql continues after each error).
\echo '--- 1. Duplicate e-mail (UNIQUE) ---'
INSERT INTO customer(full_name,email,city,state) VALUES ('Test User','user1@example.com','Ikeja','Lagos');
\echo '--- 2. Negative stock (CHECK) ---'
UPDATE product SET stock_qty = -5 WHERE product_id = 1;
\echo '--- 3. Order for a customer that does not exist (FOREIGN KEY) ---'
INSERT INTO orders(customer_id) VALUES (999999);
\echo '--- 4. Invalid order status (CHECK) ---'
UPDATE orders SET status = 'LOST' WHERE order_id = 1;
\echo '--- 5. Zero quantity on an order line (CHECK) ---'
INSERT INTO order_item(order_id, product_id, quantity, unit_price) VALUES (1, 2, 0, 100);
\echo '--- 6. Duplicate product in the same order (composite PRIMARY KEY) ---'
INSERT INTO order_item(order_id, product_id, quantity, unit_price)
SELECT order_id, product_id, 1, unit_price FROM order_item WHERE order_id = 1 LIMIT 1;
\echo '--- 7. Delivered before shipped (table CHECK) ---'
UPDATE delivery SET delivered_at = shipped_at - interval '1 day' WHERE order_id = 3;
\echo '--- 8. Trigger test: stock change is audited automatically ---'
UPDATE product SET stock_qty = stock_qty - 1 WHERE product_id = 10;
SELECT * FROM stock_audit;
