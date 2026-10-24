-- Portfolio 1 - 02_seed_data.sql
-- Generates reproducible synthetic data (setseed makes random() repeatable)
-- Volumes: 12 categories, 300 products, 20,000 customers,
--          200,000 orders, ~500,000 order lines
SELECT setseed(0.42);

-- Categories (parents 1-6, children 7-12)
INSERT INTO category(name, parent_category_id) VALUES
 ('Electronics',NULL),('Fashion',NULL),('Home & Kitchen',NULL),
 ('Groceries',NULL),('Beauty & Health',NULL),('Books & Stationery',NULL),
 ('Phones',1),('Laptops',1),('Men Clothing',2),('Women Clothing',2),
 ('Kitchen Appliances',3),('Packaged Food',4);

-- Products (300)
INSERT INTO product(sku, name, category_id, unit_price, stock_qty)
SELECT 'SKU-' || lpad(g::text, 5, '0'),
       (ARRAY['Smart','Classic','Pro','Eco','Ultra','Lite','Premium','Basic'])[1 + (g % 8)] || ' ' ||
       -- product type matches its category (category_id = 1 + g % 12)
       (ARRAY['Smart Speaker','Handbag','Dinner Set','Rice 50kg','Perfume','Notebook','Phone','Laptop','Shirt','Dress','Blender','Noodles Carton'])[1 + (g % 12)] ||
       ' ' || g,
       1 + (g % 12),
       round((500 + random() * 249500)::numeric, 2),
       50 + (random() * 450)::int
FROM generate_series(1, 300) g;

-- Customers (20,000)
INSERT INTO customer(full_name, email, phone, city, state, created_at)
SELECT (ARRAY['Chinedu','Aisha','Tunde','Ngozi','Ibrahim','Funke','Emeka','Zainab','Bola','Kemi','Segun','Amina','Uche','Halima','Femi'])[1 + (g % 15)] || ' ' ||
       (ARRAY['Okafor','Bello','Adeyemi','Eze','Musa','Balogun','Nwosu','Abubakar','Ojo','Danjuma','Okeke','Lawal'])[1 + ((g / 15) % 12)],
       'user' || g || '@example.com',
       '080' || lpad((10000000 + g)::text, 8, '0'),
       (ARRAY['Ikeja','Abuja','Port Harcourt','Ibadan','Kano','Enugu','Kaduna','Benin City'])[1 + (g % 8)],
       (ARRAY['Lagos','FCT','Rivers','Oyo','Kano','Enugu','Kaduna','Edo'])[1 + (g % 8)],
       now() - (random() * 900 || ' days')::interval
FROM generate_series(1, 20000) g;

-- Orders (200,000) over the last 24 months
INSERT INTO orders(customer_id, order_date, status)
SELECT 1 + (random() * 19999)::int,
       now() - (random() * 730 || ' days')::interval,
       CASE WHEN r < 0.05 THEN 'PENDING'
            WHEN r < 0.10 THEN 'PAID'
            WHEN r < 0.20 THEN 'SHIPPED'
            WHEN r < 0.92 THEN 'DELIVERED'
            ELSE 'CANCELLED' END
FROM (SELECT random() AS r FROM generate_series(1, 200000)) t;

-- Order items: 1-4 distinct products per order (37 is coprime with 300, so
-- (order_id*7 + k*37) mod 300 never repeats inside one order)
INSERT INTO order_item(order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 1 + (random() * 3)::int, p.unit_price
FROM orders o
JOIN LATERAL generate_series(1, 1 + (o.order_id % 4)) k ON TRUE
JOIN product p ON p.product_id = 1 + ((o.order_id * 7 + k * 37) % 300);

-- Order totals derived from the lines
UPDATE orders o SET total_amount = s.t
FROM (SELECT order_id, SUM(quantity * unit_price) AS t FROM order_item GROUP BY order_id) s
WHERE s.order_id = o.order_id;

-- Payments for every non-cancelled order that is not still pending
INSERT INTO payment(order_id, method, amount, status, paid_at)
SELECT order_id,
       (ARRAY['CARD','TRANSFER','USSD','PAY_ON_DELIVERY'])[1 + (order_id % 4)],
       total_amount, 'SUCCESS', order_date + interval '5 minutes'
FROM orders WHERE status IN ('PAID','SHIPPED','DELIVERED');

-- Deliveries for shipped / delivered orders
INSERT INTO delivery(order_id, courier, tracking_no, status, shipped_at, delivered_at)
SELECT order_id,
       (ARRAY['GIG Logistics','DHL Nigeria','Kwik Delivery','Sendbox'])[1 + (order_id % 4)],
       'TRK' || lpad(order_id::text, 9, '0'),
       CASE status WHEN 'SHIPPED' THEN 'IN_TRANSIT' ELSE 'DELIVERED' END,
       order_date + interval '1 day',
       CASE status WHEN 'DELIVERED' THEN order_date + interval '4 days' END
FROM orders WHERE status IN ('SHIPPED','DELIVERED');

ANALYZE;

-- Quick sanity check of row counts
SELECT 'category' t, count(*) FROM category UNION ALL
SELECT 'product', count(*) FROM product UNION ALL
SELECT 'customer', count(*) FROM customer UNION ALL
SELECT 'orders', count(*) FROM orders UNION ALL
SELECT 'order_item', count(*) FROM order_item UNION ALL
SELECT 'payment', count(*) FROM payment UNION ALL
SELECT 'delivery', count(*) FROM delivery;
