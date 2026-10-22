# Portfolio 3 — Transactions and Concurrency

> Status: **planned**. Uses the same TripNest database.

## Goal

Demonstrate ACID transactions and show a real concurrency problem in TripNest, along with how it is prevented.

## Planned demonstrations

| # | Scenario | Concept |
|---|---|---|
| T1 | Pay for a booking from a wallet: debit wallet, insert payment, confirm booking | `BEGIN ... COMMIT`, atomicity |
| T2 | Same payment, but the wallet balance is too low (CHECK fails) | Automatic `ROLLBACK`, nothing half-done |
| T3 | Multi-step booking that fails partway through | `SAVEPOINT` and `ROLLBACK TO SAVEPOINT` |
| T4 | **Two customers book the last seat at the same time** (two psql sessions) | Race condition / lost update |
| T5 | Fix T4 with `SELECT ... FOR UPDATE` | Pessimistic locking |
| T6 | Fix T4 with the `version` column | Optimistic locking |
| T7 | Run the same report under READ COMMITTED vs REPEATABLE READ while another session updates | Non-repeatable read, isolation levels |
| T8 | Two sessions lock seats in opposite order | Deadlock detection |

## Method

- Use **two terminal windows** side by side for the concurrency tests (T4–T8) and screenshot both.
- Number each step (Session A step 1, Session B step 1, ...) so the interleaving is clear.
- Save scripts in `sql/` and screenshots or output in `evidence/`.
