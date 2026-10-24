-- Portfolio 2 - 01_queries.sql : business queries with their RESULTS
-- Case study: NaijaMart Online   DBMS: PostgreSQL 16
SELECT '=== Q1  Order history of one customer (most recent first) ===' AS section;
SELECT order_id, order_date, status, total_amount
FROM orders WHERE customer_id = 777 ORDER BY order_date DESC LIMIT 5;

SELECT '=== Q2  Top 5 products by revenue (JOIN + GROUP BY + ORDER BY) ===' AS section;
SELECT p.product_id, p.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_item oi JOIN product p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name ORDER BY revenue DESC LIMIT 5;

SELECT '=== Q3  Pending orders older than 30 days (follow-up list) ===' AS section;
SELECT count(*) AS stale_pending_orders FROM orders
WHERE status = 'PENDING' AND order_date < now() - interval '30 days';

SELECT '=== Q4  Revenue by state, last 30 days, excluding cancelled ===' AS section;
SELECT c.state, count(*) AS orders, SUM(o.total_amount) AS revenue
FROM orders o JOIN customer c ON c.customer_id = o.customer_id
WHERE o.order_date >= now() - interval '30 days' AND o.status <> 'CANCELLED'
GROUP BY c.state ORDER BY revenue DESC;

SELECT '=== Q5a Customers with NO order in the last 180 days - NOT IN version ===' AS section;
SELECT count(*) FROM customer
WHERE customer_id NOT IN (SELECT customer_id FROM orders WHERE order_date >= now() - interval '180 days');

SELECT '=== Q5b Same question - NOT EXISTS version (query rewrite) ===' AS section;
SELECT count(*) FROM customer c
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id AND o.order_date >= now() - interval '180 days');

SELECT '=== Q6  Window function: top 2 customers by spend in each state ===' AS section;
SELECT * FROM (
  SELECT c.state, c.full_name, c.customer_id, SUM(o.total_amount) AS spend,
         RANK() OVER (PARTITION BY c.state ORDER BY SUM(o.total_amount) DESC) AS rnk
  FROM customer c JOIN orders o ON o.customer_id = c.customer_id
  WHERE o.status = 'DELIVERED'
  GROUP BY c.state, c.customer_id, c.full_name) t
WHERE rnk <= 2 ORDER BY state, rnk;
