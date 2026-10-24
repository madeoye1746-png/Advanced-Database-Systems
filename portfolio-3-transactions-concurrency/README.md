# Portfolio 3 - Transactions and Concurrency

Case study: **NaijaMart Online**. Operation studied: *placing an order*, which must (1) create the order, (2) create its lines, (3) reduce stock - all or nothing - even when hundreds of customers buy at the same moment.

All evidence below is real output from PostgreSQL 16, captured in `evidence/`.

## A. Transaction control: COMMIT, ROLLBACK, SAVEPOINT  (`01_commit_rollback.sql`)

| Scenario | What happens | Evidence (`evidence/01_commit_rollback.output.txt`) |
|---|---|---|
| 1. Successful order | order + line + stock reduction + total all `COMMIT` together | the new order is saved, stock 100 -> 97 |
| 2. Order for 500 units when 97 exist | `UPDATE stock` violates `CHECK (stock_qty >= 0)`; PostgreSQL aborts the transaction and the final `COMMIT` becomes a `ROLLBACK` | 0 new orders, 0 orphan lines, stock still 97 -> **Atomicity** and **Consistency** |
| 3. `SAVEPOINT` | customer removes one item; only that insert is undone, the order survives | order has only product 5 |
| 4. Explicit `ROLLBACK` | customer abandons checkout | row visible inside the transaction (1), gone afterwards (0) -> **Isolation** |

`02_place_order_function.sql` packages the operation as `place_order(customer, product, qty)`. It uses `SELECT ... FOR UPDATE` to lock the product row, raises an exception when stock is short (everything the function did is undone) and returns the order id when successful. Evidence: stock 5 -> order of 2 succeeds (3 left) -> order of 4 fails with `Insufficient stock` and stock stays 3.

## B. Concurrency problems and controls (two real parallel sessions, `demos/` + `pair.sh`)

Timestamps in the output prove the interleaving. Full output: `evidence/concurrency_demos_output.txt`.

| # | Problem / mechanism | What we observed | Result |
|---|---|---|---|
| 1 | **Lost update** (READ COMMITTED, app reads stock, computes `stock-1`, writes back). A reads 10 and is slow; B reads 10 and commits 9; A then writes 9 | Two items sold, stock reduced by only one | Final stock **9 (wrong, should be 8)** |
| 1a | Fix: **atomic update** `SET stock_qty = stock_qty - 1` | B's `UPDATE` waits for A's row lock and then applies on top of A's value | Final stock **8 (correct)** |
| 1b | Fix: **pessimistic locking** `SELECT ... FOR UPDATE` | B blocks at the SELECT until A commits, then reads the fresh value 9 | Final stock **8 (correct)** |
| 2a | **Non-repeatable read** at READ COMMITTED | Reader sees stock 10, then 5 inside the same transaction | Anomaly shown |
| 2b | **REPEATABLE READ** (snapshot isolation) | Reader sees 10 and 10 although the writer committed 5 | Anomaly prevented |
| 2c | **Dirty read** under `READ UNCOMMITTED` | Reader sees the committed 10, not the writer's uncommitted 1 (PostgreSQL treats READ UNCOMMITTED as READ COMMITTED) | Dirty reads impossible |
| 3 | **Deadlock**: A locks product 1 then 2; B locks 2 then 1 | After `deadlock_timeout` (1 s) PostgreSQL logs `ERROR: deadlock detected` and aborts one transaction; the other completes | Stock 9/9 (only the survivor's update) |
| 3a | Fix: **consistent lock ordering** | B simply waits for A, no error, both applied | Stock **8/8** |

### Isolation levels summary (as observed in PostgreSQL 16)

| Level | Dirty read | Non-repeatable read | Phantom read |
|---|---|---|---|
| READ UNCOMMITTED (= READ COMMITTED in PostgreSQL) | no | **possible** (shown, demo 2a) | possible |
| READ COMMITTED (default) | no (demo 2c) | **possible** | possible |
| REPEATABLE READ | no | no (demo 2b) | no (PostgreSQL snapshot isolation) |
| SERIALIZABLE | no | no | no (may abort with serialization failure; application must retry) |

### Design decision for NaijaMart
Stock changes are the hot spot, so the application uses **atomic updates / `FOR UPDATE` inside short transactions** (default READ COMMITTED), keeps `CHECK (stock_qty >= 0)` as the last line of defence, and always touches products in ascending `product_id` order to avoid deadlocks. Reports that need a consistent picture (e.g. month-end totals) run in `REPEATABLE READ`.

## Files

| File | Purpose |
|---|---|
| `00_reset_test_data.sql` | Puts products 1 and 2 at stock 10 before each demo |
| `01_commit_rollback.sql` | Commit / rollback / savepoint scenarios |
| `02_place_order_function.sql` | Safe `place_order` function |
| `demos/*.sql` | One script per session of every concurrency demo |
| `pair.sh`, `run_all_demos.sh` | Start session A, then B after a delay, print timestamps and final state |
| `evidence/` | Captured outputs |

## Reproduce
```bash
cd portfolio-3-transactions-concurrency
../run_sql.sh 01_commit_rollback.sql
../run_sql.sh 02_place_order_function.sql
./run_all_demos.sh
```
