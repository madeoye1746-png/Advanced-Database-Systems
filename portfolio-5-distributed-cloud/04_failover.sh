#!/bin/bash
# =====================================================================
# Portfolio 5 - 04_failover.sh : simulate a primary crash and promote a standby
# A disposable standby (nm-replica2) is used so the main environment is left intact.
# =====================================================================
export MSYS_NO_PATHCONV=1
h() { echo; echo "=================== $1 ==================="; }
Q() { docker exec "$1" psql -U postgres -d naijamart -c "$2" 2>&1; }

h "1. Build a disposable standby (nm-replica2, port 5436) from the primary"
docker rm -fv nm-replica2 >/dev/null 2>&1
docker run -d --name nm-replica2 --network naijamart-net -p 5436:5432 -e PGPASSWORD=repl_test --entrypoint bash postgres:16.0 -c \
  'if [ ! -s "$PGDATA/PG_VERSION" ]; then gosu postgres pg_basebackup -h nm-primary -U replicator -D "$PGDATA" -R -X stream || exit 1; fi; exec docker-entrypoint.sh postgres -c hot_standby=on' >/dev/null
for i in $(seq 1 30); do docker exec nm-replica2 pg_isready -q && break; sleep 2; done   # wait until the standby accepts connections
Q nm-primary  "SELECT 'nm-primary' AS node, pg_is_in_recovery() AS is_standby, (SELECT count(*) FROM orders) AS orders, (SELECT max(id) FROM replication_test) AS last_replication_test_id"
Q nm-replica2 "SELECT 'nm-replica2' AS node, pg_is_in_recovery() AS is_standby, (SELECT count(*) FROM orders) AS orders, (SELECT max(id) FROM replication_test) AS last_replication_test_id"

h "2. CRASH: the primary server is stopped"
T0=$(date +%s.%N)
docker stop nm-primary >/dev/null
echo "nm-primary stopped. Write attempt against it:"
Q nm-primary "INSERT INTO replication_test(note) VALUES ('write to dead primary')"

h "3. FAILOVER: promote the standby to primary"
Q nm-replica2 "SELECT pg_promote(wait => true)"
Q nm-replica2 "SELECT 'nm-replica2' AS node, pg_is_in_recovery() AS is_standby, (SELECT timeline_id FROM pg_control_checkpoint()) AS timeline"

h "4. The new primary accepts writes, and nothing committed before the crash was lost"
Q nm-replica2 "INSERT INTO replication_test(note) VALUES ('written AFTER failover') RETURNING id, note"
T1=$(date +%s.%N)
Q nm-replica2 "SELECT (SELECT count(*) FROM orders) AS orders_still_there, (SELECT count(*) FROM replication_test) AS replication_test_rows"
echo "Time from crash to first successful write on the new primary: $(echo "$T1 - $T0" | bc 2>/dev/null || python -c "print(round($T1-$T0,1))") seconds, measured from the stop command to the first successful write (includes the time Docker needs to stop the container). Promotion here was manual; tools such as Patroni or a cloud Multi-AZ service automate it"

h "5. Clean up: remove the disposable node and bring the original primary back (it never received the post-failover writes)"
docker rm -fv nm-replica2 >/dev/null
docker start nm-primary >/dev/null; sleep 8
Q nm-primary "SELECT 'nm-primary' AS node, pg_is_in_recovery() AS is_standby, (SELECT count(*) FROM replication_test) AS replication_test_rows"
Q nm-primary "SELECT application_name, state, sync_state FROM pg_stat_replication"
