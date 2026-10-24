-- =====================================================================
-- Portfolio 3 - 02_place_order_function.sql
-- A reusable, concurrency-safe "place order" operation.
-- A function body always runs inside ONE transaction: any RAISE EXCEPTION
-- undoes everything the function did.
-- SELECT ... FOR UPDATE locks the product row so two buyers cannot both
-- take the last items (prevents overselling / lost updates).
-- =====================================================================
CREATE OR REPLACE FUNCTION place_order(p_customer INT, p_product INT, p_qty INT)
RETURNS INT AS $$
DECLARE
    v_stock INT; v_price NUMERIC(12,2); v_order INT;
BEGIN
    SELECT stock_qty, unit_price INTO v_stock, v_price
    FROM product WHERE product_id = p_product AND is_active
    FOR UPDATE;                                   -- row lock until COMMIT/ROLLBACK
    IF NOT FOUND THEN RAISE EXCEPTION 'Product % not found or inactive', p_product; END IF;
    IF v_stock < p_qty THEN
        RAISE EXCEPTION 'Insufficient stock for product %: requested %, available %', p_product, p_qty, v_stock;
    END IF;

    INSERT INTO orders(customer_id, status, total_amount)
         VALUES (p_customer, 'PENDING', v_price * p_qty) RETURNING order_id INTO v_order;
    INSERT INTO order_item(order_id, product_id, quantity, unit_price) VALUES (v_order, p_product, p_qty, v_price);
    UPDATE product SET stock_qty = stock_qty - p_qty WHERE product_id = p_product;
    RETURN v_order;
END;
$$ LANGUAGE plpgsql;

UPDATE product SET stock_qty = 5 WHERE product_id = 6;
SELECT 'stock of product 6 = 5' AS section;
SELECT place_order(10, 6, 2) AS new_order_id;          -- succeeds
SELECT stock_qty AS stock_after_success FROM product WHERE product_id = 6;   -- 3
SELECT place_order(11, 6, 4) AS never_returned;        -- fails: only 3 left
SELECT stock_qty AS stock_after_failure_unchanged FROM product WHERE product_id = 6;   -- still 3
