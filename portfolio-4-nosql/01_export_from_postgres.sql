-- =====================================================================
-- Portfolio 4 - 01_export_from_postgres.sql
-- Builds JSON documents from the relational NaijaMart data (denormalised
-- for the document model). Run with psql -t -A, output = one JSON per line.
-- =====================================================================
-- PRODUCTS: variable, category-specific attributes (hard in a relational table)
\o /tmp/products.ndjson
SELECT json_build_object(
  'product_id', p.product_id, 'sku', p.sku, 'name', p.name,
  'category', c.name, 'unit_price', p.unit_price, 'stock_qty', p.stock_qty,
  'attributes',
    CASE p.category_id
      WHEN 7  THEN json_build_object('ram_gb', 4 * (1 + (p.product_id / 12) % 4), 'storage_gb', 64 * (1 + (p.product_id / 12) % 4),
                    'colour', (ARRAY['Black','Blue','Gold','Silver'])[1 + (p.product_id / 12) % 4], 'network', '5G')
      WHEN 8  THEN json_build_object('ram_gb', 8 * (1 + (p.product_id / 12) % 3), 'cpu', (ARRAY['i5','i7','Ryzen 5'])[1 + (p.product_id / 12) % 3],
                    'screen_in', 13 + (p.product_id / 12) % 4, 'warranty_months', 12)
      WHEN 9  THEN json_build_object('size', (ARRAY['S','M','L','XL'])[1 + (p.product_id / 12) % 4], 'fabric', 'Cotton',
                    'colour', (ARRAY['White','Navy','Green'])[1 + (p.product_id / 12) % 3])
      WHEN 10 THEN json_build_object('size', (ARRAY['8','10','12','14'])[1 + (p.product_id / 12) % 4], 'fabric', 'Ankara',
                    'colour', (ARRAY['Red','Yellow','Blue'])[1 + (p.product_id / 12) % 3])
      WHEN 11 THEN json_build_object('power_watts', 300 + 100 * ((p.product_id / 12) % 5), 'voltage', '220V', 'warranty_months', 24)
      WHEN 12 THEN json_build_object('weight_kg', 1 + (p.product_id / 12) % 50, 'expiry_months', 12, 'halal', true)
      ELSE json_build_object('brand', 'NaijaMart Select')
    END,
  'tags', ARRAY[lower(c.name), CASE WHEN p.unit_price > 150000 THEN 'premium' ELSE 'value' END]
)
FROM product p JOIN category c USING (category_id) ORDER BY p.product_id;

-- ORDERS: one self-contained document per order (customer snapshot + items + payment + delivery embedded)
\o /tmp/orders.ndjson
SELECT json_build_object(
  '_id', o.order_id, 'order_date', o.order_date, 'status', o.status, 'total_amount', o.total_amount,
  'customer', json_build_object('customer_id', c.customer_id, 'name', c.full_name, 'city', c.city, 'state', c.state),
  'items', (SELECT json_agg(json_build_object('product_id', oi.product_id, 'name', p.name, 'quantity', oi.quantity, 'unit_price', oi.unit_price))
            FROM order_item oi JOIN product p USING (product_id) WHERE oi.order_id = o.order_id),
  'payment',  (SELECT json_build_object('method', pa.method, 'status', pa.status) FROM payment pa WHERE pa.order_id = o.order_id),
  'delivery', (SELECT json_build_object('courier', d.courier, 'tracking_no', d.tracking_no, 'status', d.status) FROM delivery d WHERE d.order_id = o.order_id)
)
FROM orders o JOIN customer c USING (customer_id)
WHERE o.order_id <= 30000 ORDER BY o.order_id;
\o
