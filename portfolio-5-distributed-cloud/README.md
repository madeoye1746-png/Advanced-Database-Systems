# Portfolio 5 - Distributed and Cloud Database Exercise

Case study: **NaijaMart Online**. Business problem: the shop must stay available during sales events (e.g. a "Black Friday" peak), survive a server failure, and keep growing beyond what a single database server can store and serve.

Everything below was **built and run for real** as a multi-server PostgreSQL deployment in Docker (plus MongoDB from Portfolio 4). Raw outputs are in `evidence/`.

## 1. Architecture built

```
                      +-----------------------+
   writes + reads --> |  nm-primary  (5433)   |  <-- coordinator and shard 0
                      |  PostgreSQL 16        |
                      +-----+-----------+-----+
        WAL streaming       |           |   postgres_fdw (sharding)
        (replication)       v           v
              +-----------------+   +-------------------+
   reads -->  | nm-replica(5434)|   | nm-shard2 (5435)  |  shard 1 = physically separate server
              | hot standby     |   | orders_part1      |
              +-----------------+   +-------------------+

   nm-replica2 (5436): disposable standby used only to demonstrate failover
   nm-mongo   (27018): document store from Portfolio 4
```

| Script | Purpose |
|---|---|
| `01_setup_cluster.sh` | Creates the replication role, builds the replica with `pg_basebackup`, starts the second shard. This is the **deployment configuration** |
| `02_replication_demo.sh` | Replication, lag, read scaling, synchronous vs asynchronous mode, availability vs consistency |
| `03_sharding.sh` | Horizontal partitioning of `orders` over two servers |
| `04_failover.sh` | Crash of the primary and promotion of a standby |

## 2. Replication (`evidence/02_replication_demo_output.txt`)

| Test | Observation |
|---|---|
| Streaming replication | `pg_stat_replication` shows `state = streaming`, `sync_state = async` |
| Replica is read-only | `INSERT` on the replica gives `ERROR: cannot execute INSERT in a read-only transaction` (a single writer keeps data consistent) |
| Propagation | A row written on the primary was readable on the replica; 200,000 bulk-inserted rows were fully visible on the replica 2 s later |
| Read scaling | The revenue-by-status report ran on the replica, leaving the primary free for customer orders |
| Recovery | After the replica was stopped and restarted it caught up automatically (row counts and last id identical on both nodes) |

## 3. Consistency vs availability (CAP / PACELC)

| Mode | Behaviour measured | Consistency | Availability |
|---|---|---|---|
| **Asynchronous** (default) | Commit returns before the replica has the data, so replica reads can be slightly stale. With the replica stopped, the primary kept accepting writes | Eventual (on the replica) | **High** |
| **Synchronous** (`synchronous_standby_names='*'`) | Commit waits for the replica (`sync_state = sync`). With the replica **stopped**, a write received **no response within 5 s** | **Strong** (no data loss on failover) | Lower: writes block while the standby is down |

Worth knowing: the blocked insert was only *waiting for acknowledgement*. When synchronous mode was switched off, that row committed locally (final counts on both nodes include it). A client that times out therefore does **not** know whether its write happened, so applications must make writes idempotent or check afterwards.

**NaijaMart policy (design decision):** payments and stock use synchronous replication to one standby (losing a paid order is unacceptable); catalogue browsing and reports read from asynchronous replicas (a few seconds of staleness is fine). This is the PACELC trade-off: *during a partition* choose consistency or availability; *otherwise* choose latency or consistency.

## 4. Sharding (`evidence/03_sharding_output.txt`)

`orders_sharded` is partitioned by `HASH(customer_id)` into two shards. Shard 0 is a local table; shard 1 is a table stored on a **different server** (`nm-shard2`) and reached through `postgres_fdw`.

| Test | Result |
|---|---|
| Load 100,000 orders through the coordinator | 50,019 stored on shard 0, 49,981 on shard 1 (even distribution) |
| Physical proof | Querying `nm-shard2` directly returns the same 49,981 rows |
| Single-customer query (`customer_id = 777`) | Plan contains **only one** shard (partition pruning), no work on the other server |
| Cross-shard aggregate | Plan = `Append` of local scan + `Foreign Scan`; result equals the unsharded table (100,000 orders, same revenue) |
| New insert | Automatically routed to the correct shard |

**Why `customer_id` as shard key:** the most frequent query ("my orders") filters by customer so it hits exactly one shard, and hashing avoids the "hot shard" that date ranges would create during sales. **Costs:** cross-shard reports are slower (network), a cross-shard transaction needs two-phase commit, a primary key must include the shard key, and adding a third server means moving data. For this reason production systems usually use Citus or MongoDB sharding instead of hand-built `postgres_fdw`.

## 5. Failover / availability (`evidence/04_failover_output.txt`)

1. Standby `nm-replica2` built from the primary: identical data (200,006 orders).
2. Primary stopped (simulated crash): writes to it fail.
3. `SELECT pg_promote()` turns the standby into a primary (timeline 1 -> 2).
4. The new primary accepted a write immediately and **all previously committed data was present**. Crash-to-first-write time was 13.7 s, which includes the time Docker takes to stop the container; promotion was done by hand.
5. The original primary was restarted unchanged. **Split-brain warning:** in real life a restarted old primary must never accept writes alongside the promoted one. It must be rebuilt as a standby (`pg_rewind`); cluster managers such as Patroni enforce this.

## 6. Cloud deployment discussion

The same design maps onto managed cloud services. It was **not deployed on a cloud account** for this submission; the Docker cluster above is the working proof of the concepts.

| Local component | Cloud equivalent (examples) | Benefit |
|---|---|---|
| `nm-primary` + synchronous standby | AWS RDS / Aurora **Multi-AZ**, Azure Database for PostgreSQL HA, Google Cloud SQL HA | Automatic failover, no manual `pg_promote` |
| `nm-replica` | **Read replicas** (also cross-region) | Elastic read scaling for sales peaks |
| `nm-shard2` + `postgres_fdw` | Citus (Azure Cosmos DB for PostgreSQL), Aurora Limitless, MongoDB Atlas sharded cluster | Managed re-balancing |
| `nm-mongo` | **MongoDB Atlas** replica set across zones | Managed backups, scaling, monitoring |
| Backups | Automated snapshots + point-in-time recovery | Recovers from human error (a wrong `DELETE` is replicated too) |

Considerations for a Nigerian e-commerce business: pick a region close to customers (latency), follow the **Nigeria Data Protection Act (NDPA)** for personal data and cross-border transfer, encrypt at rest and in transit, use private networking instead of public database ports, and watch cost (replicas and Multi-AZ multiply the compute bill, so scale them for peak periods).

## 7. Reproduce
```bash
./01_setup_cluster.sh && ./02_replication_demo.sh && ./03_sharding.sh && ./04_failover.sh
```
(Credentials such as `repl_test` and `portfolio_test` are throw-away values for local Docker containers only.)
