# Quick explanation notes (for a possible technical verification)

Know these well; they are the questions an assessor is most likely to ask about *your* submission.

1. **Why this case study?** E-commerce: stock/orders/payments need ACID (PostgreSQL), the catalogue needs flexible attributes (MongoDB).
2. **Why is `order_item.unit_price` duplicated?** Price snapshot: later price changes must not rewrite history. `orders.total_amount` is stored to avoid re-aggregating lines.
3. **Show 3NF:** product name depends only on `product_id` (not on order), customer city on `customer_id`, etc. - each fact is stored once.
4. **Q1 speed-up (19.6 ms -> 0.18 ms):** composite index `(customer_id, order_date DESC)`: equality column first, then the sort column, so no sort step is needed.
5. **Why did the index on `order_item` not help Q2?** The query reads 100 % of the rows; a sequential scan is cheaper than 500,000 index lookups. A materialized view pre-computes the answer (needs refresh).
6. **Partial vs covering index:** partial = only rows matching a condition (PENDING); covering = `INCLUDE` extra columns so an Index Only Scan never touches the table.
7. **Lost update:** both sessions read 10, each wrote 9. Fix: `SET stock_qty = stock_qty - 1` (atomic) or `SELECT ... FOR UPDATE` (lock first).
8. **READ COMMITTED vs REPEATABLE READ:** the second read inside one transaction can change under READ COMMITTED; REPEATABLE READ uses one snapshot. PostgreSQL has no dirty reads.
9. **Deadlock:** A holds row 1 wants row 2, B holds row 2 wants row 1. PostgreSQL aborts one after `deadlock_timeout`. Prevent by always locking in the same order.
10. **Embedding vs referencing in MongoDB:** items are embedded (read together, small, bounded); customer is a snapshot copy.
11. **Sync vs async replication:** sync = no data loss but writes block if the standby is down (consistency over availability); async = fast and available but a replica can lag or lose the last commits on failover.
12. **Why shard by `customer_id` with hash?** "My orders" hits one shard; hash spreads load evenly. Cost: cross-shard queries/transactions are harder.
13. **What did you NOT do?** No real cloud deployment (discussed only), data is synthetic, single-machine Docker, failover was manual.
