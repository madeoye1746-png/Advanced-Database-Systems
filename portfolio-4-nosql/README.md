# Portfolio 4 - NoSQL and Advanced Data Models

Case study: **NaijaMart Online** (same business as Portfolios 1-3). Implemented in **MongoDB 7** (document store, Docker container `nm-mongo`), loading **real data exported from the PostgreSQL database**: 300 products and 30,000 orders.

## 1. Which NoSQL model fits which NaijaMart need?

| NaijaMart need | Best model | Implemented here? | Why |
|---|---|---|---|
| Product catalogue (phones have RAM/storage, shirts have size/fabric, generators have kVA) | **Document** | **Yes** - `products` | Every product carries its own attributes; no sparse columns or `ALTER TABLE` |
| Order history page (order + customer + items + payment + delivery) | **Document** | **Yes** - `orders` | One read returns everything the page needs (no 5-table JOIN) |
| Shopping cart / session (temporary, looked up by id, expires) | **Key-value** | **Yes** - `carts` (key = `session:...`, TTL index) | O(1) lookup by key, auto-expiry. In production this is typically Redis |
| "Customers also bought" recommendations | **Graph** | Query pattern shown with `$unwind/$group` (section 7 of the script) | Co-purchase is a relationship problem; at scale Neo4j fits best |
| Courier GPS / tracking event stream (millions of time-stamped rows) | **Column-family** (Cassandra) | Discussed only | Write-heavy, time-series, partitioned by tracking number |

The transactional core (stock, payments) stays in PostgreSQL where ACID is essential (Portfolio 3); MongoDB serves read-heavy, flexible-schema needs. This mix is called **polyglot persistence**.

## 2. Document design (embedding vs referencing)

```jsonc
// orders collection - ONE self-contained document per order
{ "_id": 1, "order_date": ISODate("2025-09-27"), "status": "DELIVERED", "total_amount": 871948.70,
  "customer": { "customer_id": 19538, "name": "Bola Nwosu", "city": "Port Harcourt", "state": "Rivers" },
  "items":    [ { "product_id": 45, "name": "Lite Dress 45", "quantity": 2, "unit_price": 49508.07 }, ... ],
  "payment":  { "method": "TRANSFER", "status": "SUCCESS" },
  "delivery": { "courier": "DHL Nigeria", "tracking_no": "TRK000000001", "status": "DELIVERED" } }

// products collection - flexible attributes per category
{ "product_id": 6, "sku": "SKU-00006", "name": "Premium Phone 6", "category": "Phones", "unit_price": 142596.29,
  "stock_qty": 3, "attributes": { "ram_gb": 12, "storage_gb": 192, "colour": "Gold", "network": "5G" }, "tags": ["phones","value"] }
```

| Decision | Choice | Reason |
|---|---|---|
| Order items | **Embedded** array | Always read with the order, small bounded size (1-4 lines), never queried alone |
| Customer in order | **Embedded snapshot** (name, city, state) | Order history must show the details *as they were at purchase time*; duplication is intentional |
| Product in order line | Embedded `product_id` + name + price | Same snapshot logic; `product_id` still allows a lookup in `products` |
| Product attributes | Nested sub-document | Different per category |

Trade-off accepted: duplicated data and no JOIN-based integrity. MongoDB offers `$jsonSchema` validation (demonstrated: a product with a negative price is rejected with error 121).

## 3. Implementation evidence (`evidence/`)

| Step | File | What it proves |
|---|---|---|
| Export relational -> JSON | `01_export_from_postgres.sql` | Data model transformed from 3NF tables into documents |
| Import | `02_import.sh`, `evidence/02_import_output.txt` | 300 products and 30,000 orders loaded, dates converted to BSON dates |
| CRUD, queries, aggregation, indexes, TTL | `03_mongo_operations.js`, `evidence/03_mongo_operations_output.txt` | All operations run with real output |

Operations covered: `insertOne`, `find` with nested / array / range filters, `updateOne` with `$inc` `$set` `$push`, `updateMany`, `deleteOne`, aggregation pipelines (`$match $group $sort $unwind $multiply`), schema validation, indexes (compound, multikey), `explain("executionStats")`, TTL index, upsert.

### Index impact (from `explain("executionStats")`)

| Query | Before (documents examined) | After (documents examined) |
|---|---|---|
| Orders of customer 777 | **30,000** (collection scan) | **2** (compound index `customer.customer_id, order_date`) |
| Orders containing product 45 | 30,000 | 300 (multikey index on `items.product_id`) |
| Phones with RAM >= 8 GB | 300 | 18 (compound index `category, attributes.ram_gb`) |

Documents examined is the reliable metric; millisecond timings in a small container are noisy.

## 4. Suitability: why MongoDB here, and where it is *not* suitable

**Good fit:** flexible product attributes, read-heavy order-history and catalogue pages, horizontal scaling by sharding on `customer.customer_id`, expiring carts.
**Poor fit:** multi-row financial consistency (stock + payment must be atomic - kept in PostgreSQL, see Portfolio 3), ad-hoc many-to-many reporting across entities (SQL JOINs are simpler), data that must never be duplicated.
**CAP view:** MongoDB replica sets favour consistency (single primary for writes) - discussed further in Portfolio 5.

## 5. Reproduce
```bash
docker run -d --name nm-mongo --network naijamart-net -p 27018:27017 mongo:7
./02_import.sh                                   # needs data/*.ndjson from 01_export (orders.ndjson is git-ignored: 17 MB)
docker cp 03_mongo_operations.js nm-mongo:/tmp/ops.js && docker exec nm-mongo mongosh --quiet /tmp/ops.js
```
Note: product names/data are synthetic; the co-purchase pattern (300 / 200 / 100) looks regular because the seed script assigns order lines by formula.
