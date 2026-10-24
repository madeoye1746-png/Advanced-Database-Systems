#!/bin/bash
# =====================================================================
# Portfolio 5 - 03_sharding.sh : horizontal partitioning (sharding) across TWO servers
# Orders are split by HASH(customer_id): shard 0 = local partition on nm-primary,
# shard 1 = a table that physically lives on the other server nm-shard2,
# reached through postgres_fdw (foreign data wrapper). Needs 01_setup_cluster.sh first.
# =====================================================================
export MSYS_NO_PATHCONV=1
P="docker exec nm-primary psql -U postgres -d naijamart"
S="docker exec nm-shard2  psql -U postgres -d naijamart"
h() { echo; echo "=================== $1 ==================="; }

h "1. Create the remote shard table on nm-shard2 and the partitioned table on the coordinator"
$S -c "DROP TABLE IF EXISTS orders_part1; CREATE TABLE orders_part1 (order_id int NOT NULL, customer_id int NOT NULL, order_date timestamp, status varchar(15), total_amount numeric(14,2));"
docker exec -i nm-primary psql -U postgres -d naijamart <<'SQL'
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
DROP TABLE IF EXISTS orders_sharded CASCADE;
DROP SERVER IF EXISTS shard2 CASCADE;
CREATE SERVER shard2 FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host 'nm-shard2', port '5432', dbname 'naijamart', batch_size '1000');
CREATE USER MAPPING FOR postgres SERVER shard2 OPTIONS (user 'postgres', password 'portfolio_test');

CREATE TABLE orders_sharded (
    order_id int NOT NULL, customer_id int NOT NULL, order_date timestamp, status varchar(15), total_amount numeric(14,2)
) PARTITION BY HASH (customer_id);                       -- the SHARD KEY is customer_id
CREATE TABLE orders_shard0 PARTITION OF orders_sharded FOR VALUES WITH (MODULUS 2, REMAINDER 0);
CREATE FOREIGN TABLE orders_shard1 PARTITION OF orders_sharded FOR VALUES WITH (MODULUS 2, REMAINDER 1)
       SERVER shard2 OPTIONS (table_name 'orders_part1');
SQL

h "2. Load 100,000 orders through the coordinator: each row is routed to its shard automatically"
$P -c "INSERT INTO orders_sharded SELECT order_id, customer_id, order_date, status, total_amount FROM orders WHERE order_id <= 100000"
$P -c "SELECT tableoid::regclass AS shard, count(*) AS orders FROM orders_sharded GROUP BY 1 ORDER BY 1"

h "3. Proof the data is PHYSICALLY on the second server (query nm-shard2 directly)"
$S -c "SELECT 'nm-shard2' AS server, count(*) AS orders_stored_here FROM orders_part1"
$P -c "SELECT 'nm-primary' AS server, count(*) AS orders_stored_here FROM orders_shard0"

h "4. Single-shard query: WHERE customer_id = 777 touches ONE shard only (partition pruning)"
$P -c "EXPLAIN (COSTS OFF) SELECT * FROM orders_sharded WHERE customer_id = 777"
$P -c "EXPLAIN (COSTS OFF) SELECT * FROM orders_sharded WHERE customer_id = 778"

h "5. Cross-shard query: aggregate over BOTH shards - result must equal the unsharded table"
$P -c "EXPLAIN (COSTS OFF) SELECT status, count(*), sum(total_amount) FROM orders_sharded GROUP BY status"
$P -c "SELECT 'sharded  (2 servers)' AS source, count(*) AS orders, round(sum(total_amount)) AS revenue FROM orders_sharded
       UNION ALL
       SELECT 'original (1 server)', count(*), round(sum(total_amount)) FROM orders WHERE order_id <= 100000"

h "6. New order for customer 12345 is routed automatically"
$P -c "INSERT INTO orders_sharded VALUES (900001, 12345, now(), 'PENDING', 25000) RETURNING tableoid::regclass AS stored_on_shard, order_id, customer_id"
