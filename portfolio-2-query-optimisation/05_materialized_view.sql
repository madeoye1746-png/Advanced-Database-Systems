-- =====================================================================
-- Portfolio 2 - 05_materialized_view.sql
-- Q2 reads every order line, so an index cannot help (the planner is right
-- to ignore it). The correct fix is to PRE-AGGREGATE the result.
-- =====================================================================
DROP MATERIALIZED VIEW IF EXISTS mv_product_revenue;
CREATE MATERIALIZED VIEW mv_product_revenue AS
SELECT p.product_id, p.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_item oi JOIN product p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.name;
CREATE UNIQUE INDEX ON mv_product_revenue (product_id);  -- also allows REFRESH ... CONCURRENTLY

SELECT 'Q2 again, answered from the materialized view' AS section;
EXPLAIN (ANALYZE, BUFFERS)
SELECT product_id, name, revenue FROM mv_product_revenue ORDER BY revenue DESC LIMIT 5;
SELECT product_id, name, revenue FROM mv_product_revenue ORDER BY revenue DESC LIMIT 5;
-- Trade-off: data is only as fresh as the last  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_revenue;
