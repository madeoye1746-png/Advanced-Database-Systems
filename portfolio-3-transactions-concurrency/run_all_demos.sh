#!/bin/bash
# Re-creates evidence/concurrency_demos_output.txt (needs the nm-primary container running)
cd "$(dirname "$0")"
{
./pair.sh "DEMO 1 - LOST UPDATE: two buyers each buy 1 of 10 items. Correct final stock = 8" lost_update_A.sql lost_update_B.sql
./pair.sh "DEMO 1 FIX (a) - atomic UPDATE stock_qty = stock_qty - 1. B waits for A's row lock. Correct final stock = 8" fix_atomic_A.sql fix_atomic_B.sql
./pair.sh "DEMO 1 FIX (b) - pessimistic locking SELECT ... FOR UPDATE. Correct final stock = 8" fix_forupdate_A.sql fix_forupdate_B.sql
./pair.sh "DEMO 2a - NON-REPEATABLE READ under READ COMMITTED" isolation_rc_reader.sql isolation_writer.sql 1
./pair.sh "DEMO 2b - REPEATABLE READ gives the reader a stable snapshot" isolation_rr_reader.sql isolation_writer.sql 1
./pair.sh "DEMO 2c - DIRTY READ is impossible in PostgreSQL" dirty_writer.sql dirty_reader.sql 1
./pair.sh "DEMO 3 - DEADLOCK" deadlock_A.sql deadlock_B.sql 0.5
./pair.sh "DEMO 3 FIX - same lock order" deadlock_A.sql deadlock_fixed_B.sql 0.5
} > evidence/concurrency_demos_output.txt 2>&1
