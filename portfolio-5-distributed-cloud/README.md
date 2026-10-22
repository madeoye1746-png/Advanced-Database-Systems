# Portfolio 5 — Distributed and Cloud Database Exercise

> Status: **planned**.

## Planned setup — `docker/`

**PostgreSQL streaming replication.** One primary and one read replica, run with Docker Compose.
- Write a booking on the primary and read it on the replica.
- Measure replication lag.
- Show that the replica rejects writes (`read-only transaction`).
- Stop the primary and promote the replica (manual failover).

**Optional:** a MongoDB replica set (three nodes) to compare its automatic failover with PostgreSQL's manual promotion.

**Optional cloud evidence:** AWS RDS PostgreSQL with a read replica. Take screenshots, then delete it to avoid charges.

## Discussion topics (to write)

- **Replication for TripNest:** search traffic is routed to replicas; bookings and payments go to the primary.
- **Sharding:** how bookings could be sharded by `customer_id` or by region, and why flight inventory is harder to shard.
- **CAP / consistency:** search results can be slightly stale (eventual consistency), but seat inventory and payments need strong consistency.
- **Availability:** what happens to bookings during a primary failure.

## Evidence

Store config files in `docker/` and terminal output and screenshots in `evidence/`.
