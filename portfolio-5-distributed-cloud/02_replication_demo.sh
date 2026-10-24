#!/bin/bash
# =====================================================================
# Portfolio 5 - 02_replication_demo.sh : replication, consistency, availability
# =====================================================================
export MSYS_NO_PATHCONV=1
P="docker exec nm-primary psql -U postgres -d naijamart"
R="docker exec nm-replica psql -U postgres -d naijamart"
h() { echo; echo "=================== $1 ==================="; }
for i in $(seq 1 30); do docker exec nm-replica pg_isready -q && break; sleep 2; done   # wait until the replica is ready

h "A. Replication status as seen from the PRIMARY (pg_stat_replication)"
$P -c "SELECT application_name, client_addr, state, sync_state, pg_wal_lsn_diff(sent_lsn, replay_lsn) AS bytes_behind FROM pg_stat_replication"

h "B. Roles: primary is read-write, replica is in recovery (read-only)"
$P -c "SELECT 'nm-primary' AS node, pg_is_in_recovery() AS is_replica"
$R -c "SELECT 'nm-replica' AS node, pg_is_in_recovery() AS is_replica"

h "C. A write on the primary appears on the replica (ASYNCHRONOUS replication = eventually consistent reads)"
$P -c "DROP TABLE IF EXISTS replication_test; CREATE TABLE replication_test(id serial PRIMARY KEY, note text, created timestamptz DEFAULT clock_timestamp());" > /dev/null
sleep 1
$P -c "INSERT INTO replication_test(note) VALUES ('order #200100 placed on primary') RETURNING id, note, created"
$R -c "SELECT id, note, created, clock_timestamp() AS read_on_replica_at FROM replication_test"

h "D. Writes on the replica are rejected (protects consistency: only ONE node accepts writes)"
$R -c "INSERT INTO replication_test(note) VALUES ('try to write on replica')" 2>&1

h "E. Replication lag under load: insert 200,000 rows on the primary, then compare WAL positions"
$P -c "INSERT INTO replication_test(note) SELECT 'bulk ' || g FROM generate_series(1,200000) g" > /dev/null
$P -c "SELECT pg_wal_lsn_diff(sent_lsn, replay_lsn) AS bytes_behind_right_after_bulk_insert FROM pg_stat_replication"
sleep 2
$R -c "SELECT count(*) AS rows_visible_on_replica_2s_later FROM replication_test"

h "F. Read scaling: reporting query served by the REPLICA, leaving the primary free for orders"
$R -c "SELECT status, count(*), round(sum(total_amount)) AS revenue FROM orders GROUP BY status ORDER BY 2 DESC"

h "G. Switch to SYNCHRONOUS replication: the commit waits until the replica confirms (stronger consistency)"
$P -c "ALTER SYSTEM SET synchronous_standby_names = '*'" -c "SELECT pg_reload_conf()" > /dev/null
sleep 1
$P -c "SELECT application_name, state, sync_state FROM pg_stat_replication"
$P -c "INSERT INTO replication_test(note) VALUES ('sync commit while replica is up') RETURNING id, created"

h "H. Availability vs consistency (CAP): stop the replica, then try to commit a write with a 5-second limit"
docker stop nm-replica > /dev/null
echo "--> replica stopped; INSERT on primary (synchronous mode):"
timeout 5 docker exec nm-primary psql -U postgres -d naijamart -c "INSERT INTO replication_test(note) VALUES ('sync commit while replica is DOWN')" 2>&1 || echo "--> NO RESPONSE after 5 s: the primary refuses to acknowledge the commit without its synchronous standby (consistency kept, availability lost)"
echo "--> go back to ASYNCHRONOUS mode: the primary stays available"
$P -c "ALTER SYSTEM RESET synchronous_standby_names" -c "SELECT pg_reload_conf()" > /dev/null
sleep 1
$P -c "INSERT INTO replication_test(note) VALUES ('async commit while replica is DOWN') RETURNING id, note"
docker start nm-replica > /dev/null; sleep 6
echo "--> replica restarted; it catches up automatically from the primary's WAL:"
$R -c "SELECT count(*) AS rows_on_replica_after_catch_up, max(id) AS last_id FROM replication_test"
$P -c "SELECT count(*) AS rows_on_primary, max(id) AS last_id FROM replication_test"
