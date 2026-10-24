#!/bin/bash
# =====================================================================
# Portfolio 5 - 01_setup_cluster.sh
# Builds a small distributed PostgreSQL deployment with Docker:
#   nm-primary  (5433) : primary / read-write node (already created in Portfolio 1)
#   nm-replica  (5434) : hot-standby replica, streaming replication from the primary
#   nm-shard2   (5435) : second shard (data node) used by the sharding demo
# =====================================================================
export MSYS_NO_PATHCONV=1
NET=naijamart-net

echo "## 1. Replication role + access rule on the primary"
docker exec nm-primary psql -U postgres -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='replicator') THEN CREATE ROLE replicator REPLICATION LOGIN PASSWORD 'repl_test'; END IF; END \$\$;"
docker exec nm-primary sh -c 'grep -q "replicator" $PGDATA/pg_hba.conf || echo "host replication replicator all scram-sha-256" >> $PGDATA/pg_hba.conf'
docker exec nm-primary psql -U postgres -c "SELECT pg_reload_conf();"

echo "## 2. Start the replica: pg_basebackup copies the primary (first start only), -R writes standby.signal + primary_conninfo"
docker rm -fv nm-replica >/dev/null 2>&1
docker run -d --name nm-replica --network $NET -p 5434:5432 -e PGPASSWORD=repl_test --entrypoint bash postgres:16.0 -c \
  'if [ ! -s "$PGDATA/PG_VERSION" ]; then gosu postgres pg_basebackup -h nm-primary -U replicator -D "$PGDATA" -R -X stream -P || exit 1; fi; exec docker-entrypoint.sh postgres -c hot_standby=on'

echo "## 3. Start the second shard (empty PostgreSQL)"
docker rm -fv nm-shard2 >/dev/null 2>&1
docker run -d --name nm-shard2 --network $NET -p 5435:5432 -e POSTGRES_PASSWORD=portfolio_test -e POSTGRES_DB=naijamart postgres:16.0
sleep 15
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' | grep -E "NAMES|nm-"
