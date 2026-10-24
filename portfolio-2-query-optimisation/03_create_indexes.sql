-- Portfolio 2 - 03_create_indexes.sql : one targeted index per bottleneck
-- Q1/Q5 : composite index, equality column first then the sort column
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date DESC);
-- Q2    : NO index here on purpose. An index on order_item(product_id) was tried and the
--         planner ignored it, because Q2 must read ALL 500,000 lines. See 05_materialized_view.sql.
-- Q3    : partial index - only the 5 % of rows that are PENDING
CREATE INDEX idx_orders_pending ON orders (order_date) WHERE status = 'PENDING';
-- Q4    : date range scan that also carries the columns the query needs
CREATE INDEX idx_orders_date ON orders (order_date) INCLUDE (customer_id, total_amount, status);
ANALYZE;
SELECT indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes WHERE schemaname='public' AND indexname LIKE 'idx_%';
