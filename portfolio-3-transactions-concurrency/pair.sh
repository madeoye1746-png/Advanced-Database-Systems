#!/bin/bash
# Usage: ./pair.sh <title> <sessionA.sql> <sessionB.sql> [delay_seconds_before_B=0.5]
# Resets test data, starts session A, starts session B after a delay, prints both
# sessions' output and the final stock of the test products.
cd "$(dirname "$0")"
TITLE="$1"; A="$2"; B="$3"; D="${4:-0.5}"
KEEP='^(Output format|Field separator|Tuples only|BEGIN|COMMIT|ROLLBACK|UPDATE [0-9]|SELECT [0-9]|$)'
../run_sql.sh 00_reset_test_data.sql < /dev/null > /dev/null 2>&1
echo "################ $TITLE ################"
../run_sql.sh "demos/$A" < /dev/null > /tmp/outA.$$ 2>&1 &
PA=$!
sleep "$D"
../run_sql.sh "demos/$B" < /dev/null > /tmp/outB.$$ 2>&1 &
PB=$!
wait $PA $PB
echo "----- Session A ($A) -----"; grep -v -E "$KEEP" /tmp/outA.$$
echo "----- Session B ($B) -----"; grep -v -E "$KEEP" /tmp/outB.$$
echo "----- Final state -----"
docker exec nm-primary psql -U postgres -d naijamart -c "SELECT product_id, stock_qty FROM product WHERE product_id IN (1,2) ORDER BY 1"
rm -f /tmp/outA.$$ /tmp/outB.$$
