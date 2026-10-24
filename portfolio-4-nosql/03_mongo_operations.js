// =====================================================================
// Portfolio 4 - 03_mongo_operations.js   (run with mongosh)
// Case study: NaijaMart Online - document model in MongoDB 7
// =====================================================================
db = db.getSiblingDB("naijamart");
const h = (t) => print("\n=== " + t + " ===");

h("0. Schema validation: the document model is flexible, but not lawless");
db.runCommand({ collMod: "products", validator: { $jsonSchema: {
  bsonType: "object", required: ["sku", "name", "unit_price", "stock_qty"],
  properties: { unit_price: { bsonType: ["double", "int", "decimal"], minimum: 0 },
                stock_qty:  { bsonType: ["int", "long", "double"], minimum: 0 } } } }, validationAction: "error" });
try { db.products.insertOne({ sku: "BAD-1", name: "Broken", unit_price: -5, stock_qty: 3 }); }
catch (e) { print("Rejected invalid product (error code " + e.code + "): " + e.message); }

h("1. CREATE - a product with its OWN attributes (no ALTER TABLE needed)");
printjson(db.products.insertOne({ product_id: 9001, sku: "SKU-09001", name: "Solar Inverter 3kVA", category: "Home & Kitchen",
  unit_price: 450000, stock_qty: 12, attributes: { power_kva: 3, battery: "Lithium", warranty_months: 36, solar_ready: true }, tags: ["power", "premium"] }));

h("2. READ - nested-attribute filters");
print("Phones with >= 8 GB RAM in Blue:");
db.products.find({ category: "Phones", "attributes.ram_gb": { $gte: 8 }, "attributes.colour": "Blue" }, { _id: 0, name: 1, unit_price: 1, attributes: 1 }).limit(3).forEach(printjson);
print("Delivered orders in Lagos above N1,000,000 (count): " +
  db.orders.countDocuments({ status: "DELIVERED", "customer.state": "Lagos", total_amount: { $gt: 1000000 } }));
print("Orders that contain product 45 (array query, count): " + db.orders.countDocuments({ "items.product_id": 45 }));

h("3. UPDATE - atomic operators");
db.products.updateOne({ product_id: 9001 }, { $inc: { stock_qty: -2 }, $set: { "attributes.warranty_months": 48 }, $push: { tags: "bestseller" } });
printjson(db.products.findOne({ product_id: 9001 }, { _id: 0, name: 1, stock_qty: 1, "attributes.warranty_months": 1, tags: 1 }));
print("Flag SHIPPED orders older than 2026-09-24 for follow-up (documents modified): " +
  db.orders.updateMany({ status: "SHIPPED", order_date: { $lt: ISODate("2026-09-24") } }, { $set: { review_flag: true } }).modifiedCount);

h("4. DELETE");
printjson(db.products.deleteOne({ product_id: 9001 }));

h("5. AGGREGATION PIPELINE - revenue by state (30,000-order sample)");
db.orders.aggregate([
  { $match: { status: { $ne: "CANCELLED" } } },
  { $group: { _id: "$customer.state", orders: { $sum: 1 }, revenue: { $sum: "$total_amount" } } },
  { $sort: { revenue: -1 } }, { $limit: 4 }
]).forEach(printjson);

h("6. AGGREGATION - top 5 products by units sold ($unwind the embedded items array)");
db.orders.aggregate([
  { $unwind: "$items" },
  { $group: { _id: "$items.name", units: { $sum: "$items.quantity" }, revenue: { $sum: { $multiply: ["$items.quantity", "$items.unit_price"] } } } },
  { $sort: { units: -1 } }, { $limit: 5 }
]).forEach(printjson);

h("7. 'Customers also bought' (graph-style relationship query on co-purchase)");
db.orders.aggregate([
  { $match: { "items.product_id": 45 } }, { $unwind: "$items" },
  { $match: { "items.product_id": { $ne: 45 } } },
  { $group: { _id: "$items.name", times_bought_together: { $sum: 1 } } },
  { $sort: { times_bought_together: -1 } }, { $limit: 3 }
]).forEach(printjson);

h("8. INDEXING - explain('executionStats') before and after");
function stats(label, cursor) {
  const s = cursor.explain("executionStats").executionStats;
  print(label + " -> docsExamined=" + s.totalDocsExamined + ", keysExamined=" + s.totalKeysExamined +
        ", returned=" + s.nReturned + ", time=" + s.executionTimeMillis + " ms");
}
db.orders.dropIndexes(); db.products.dropIndexes();
print("-- BEFORE indexes (collection scan)");
stats("orders by customer 777  ", db.orders.find({ "customer.customer_id": 777 }));
stats("orders containing prod 45", db.orders.find({ "items.product_id": 45 }));
stats("phones RAM>=8          ", db.products.find({ category: "Phones", "attributes.ram_gb": { $gte: 8 } }));
db.orders.createIndex({ "customer.customer_id": 1, order_date: -1 });
db.orders.createIndex({ "items.product_id": 1 });                 // multikey index on an array field
db.products.createIndex({ category: 1, "attributes.ram_gb": 1 });  // compound index on a nested field
print("-- AFTER indexes");
stats("orders by customer 777  ", db.orders.find({ "customer.customer_id": 777 }));
stats("orders containing prod 45", db.orders.find({ "items.product_id": 45 }));
stats("phones RAM>=8          ", db.products.find({ category: "Phones", "attributes.ram_gb": { $gte: 8 } }));

h("9. KEY-VALUE style use: shopping carts that expire by themselves (TTL index)");
db.carts.drop();
db.carts.createIndex({ updated_at: 1 }, { expireAfterSeconds: 3600 });   // carts vanish after 1 hour of inactivity
db.carts.updateOne({ _id: "session:abc123" }, { $set: { customer_id: 777, updated_at: new Date() }, $push: { items: { product_id: 45, qty: 1 } } }, { upsert: true });
db.carts.updateOne({ _id: "session:abc123" }, { $push: { items: { product_id: 82, qty: 2 } }, $set: { updated_at: new Date() } });
printjson(db.carts.findOne({ _id: "session:abc123" }));   // O(1) lookup by key
