-- Portfolio 2 - 02_explain.sql : execution plans (run BEFORE and AFTER indexing)
SELECT '##### Q1 customer history' AS section;
EXPLAIN (ANALYZE, BUFFERS) SELECT order_id, order_date, status, total_amount
FROM orders WHERE customer_id = 777 ORDER BY order_date DESC LIMIT 5;

SELECT '##### Q2 top products' AS section;
EXPLAIN (ANALYZE, BUFFERS) SELECT p.product_id, p.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_item oi JOIN product p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name ORDER BY revenue DESC LIMIT 5;

SELECT '##### Q3 stale pending orders' AS section;
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM orders
WHERE status = 'PENDING' AND order_date < now() - interval '30 days';

SELECT '##### Q4 revenue by state last 30 days' AS section;
EXPLAIN (ANALYZE, BUFFERS) SELECT c.state, count(*), SUM(o.total_amount)
FROM orders o JOIN customer c ON c.customer_id = o.customer_id
WHERE o.order_date >= now() - interval '30 days' AND o.status <> 'CANCELLED'
GROUP BY c.state ORDER BY 3 DESC;

SELECT '##### Q5a NOT IN' AS section;
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM customer
WHERE customer_id NOT IN (SELECT customer_id FROM orders WHERE order_date >= now() - interval '180 days');

SELECT '##### Q5b NOT EXISTS' AS section;
EXPLAIN (ANALYZE, BUFFERS) SELECT count(*) FROM customer c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.order_date >= now() - interval '180 days');
