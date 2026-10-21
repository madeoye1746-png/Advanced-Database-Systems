# Portfolio 2 — Query Processing and Optimisation

> Status: **planned**. Builds on the Portfolio 1 database (run its four scripts first).

## Goal

Show how PostgreSQL executes realistic TripNest queries, then improve them with indexing and query rewrites, measuring each change with `EXPLAIN (ANALYZE, BUFFERS)`.

## Planned queries

| # | Business question | Concept it demonstrates |
|---|---|---|
| Q1 | Available flights from LOS to DXB on a given date | Seq Scan → composite B-tree index `(origin_iata, destination_iata, departure_time)` |
| Q2 | A customer's full booking history | Index on the foreign key `booking.customer_id`, Nested Loop vs Hash Join |
| Q3 | Monthly revenue by service type (flight, hotel, tour) | Aggregation over large joins, HashAggregate |
| Q4 | Flight load factor (seats sold / total seats) | Join + GROUP BY; rewrite comparison |
| Q5 | Look up a booking by reference | Unique index point lookup |
| Q6 | Only *available* seats on a flight | Partial index `WHERE is_available` |
| Q7 | Pending payments in the last 7 days | Index on low-selectivity vs high-selectivity columns |

## Method for each query

1. Run `EXPLAIN (ANALYZE, BUFFERS)` **before** any index and save the plan to `results/qN-before.txt`.
2. Explain the plan in plain words: scan type, join type, estimated vs actual rows, time.
3. Add an index or rewrite the query.
4. Run it again and save `results/qN-after.txt`.
5. Record execution time before and after in the summary table below.

## Results summary (fill in)

| Query | Before (ms) | After (ms) | Change made | Why it helped |
|---|---|---|---|---|
| Q1 | | | | |

## Folders

- `sql/` — query scripts and index scripts
- `results/` — saved execution plans and screenshots
