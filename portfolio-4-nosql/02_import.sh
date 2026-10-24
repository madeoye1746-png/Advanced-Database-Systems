#!/bin/bash
# Loads the exported documents into MongoDB (container nm-mongo, database naijamart)
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")"
docker cp data/products.ndjson nm-mongo:/tmp/products.ndjson
docker cp data/orders.ndjson   nm-mongo:/tmp/orders.ndjson
docker exec nm-mongo mongoimport --db naijamart --collection products --drop --file /tmp/products.ndjson
docker exec nm-mongo mongoimport --db naijamart --collection orders   --drop --file /tmp/orders.ndjson
# order_date arrives as text -> convert to a real BSON date
docker exec nm-mongo mongosh --quiet naijamart --eval '
  db.orders.updateMany({}, [{ $set: { order_date: { $dateFromString: { dateString: { $substr: ["$order_date", 0, 23] } } } } }]);
  print("orders:", db.orders.countDocuments(), " products:", db.products.countDocuments());
  printjson(db.orders.findOne({_id: 1}));'
