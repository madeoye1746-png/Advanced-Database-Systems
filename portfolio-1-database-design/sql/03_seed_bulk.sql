-- =====================================================================
-- TripNest — Bulk simulated data generator
-- Produces enough rows for meaningful execution plans in Portfolio 2.
-- Default volume: 50k customers, 20k flights (600k seats), 200k bookings.
-- Change the numbers in the CALL at the bottom to scale up or down.
-- Run after 02_seed_reference.sql.
-- =====================================================================
SET search_path TO tripnest;

CREATE OR REPLACE PROCEDURE seed_bulk(p_customers INT, p_flights INT, p_bookings INT)
LANGUAGE plpgsql AS $$
DECLARE
    airports CHAR(3)[] := ARRAY(SELECT iata_code FROM airport ORDER BY iata_code);
    airlines CHAR(2)[] := ARRAY(SELECT airline_code FROM airline ORDER BY airline_code);
    n_airports INT := array_length(airports, 1);
BEGIN
    PERFORM setseed(0.42);   -- reproducible "random" data

    -- Customers, one passport each, one wallet each
    INSERT INTO customer (first_name, last_name, email, phone, date_of_birth, created_at)
    SELECT (ARRAY['Ada','Bola','Chinedu','Dayo','Emeka','Fatima','Gbenga','Hauwa','Ifeoma','Kunle','Lola','Musa','Ngozi','Ola','Sade','Uche','Yusuf','Zainab'])[1 + (i % 18)],
           (ARRAY['Adeyemi','Okeke','Bello','Eze','Ibrahim','Ogunleye','Nwachukwu','Abubakar','Balogun','Okafor','Lawal','Danjuma'])[1 + (i % 12)],
           'customer' || i || '@mail.test',
           '+23480' || lpad((i % 100000000)::text, 8, '0'),
           DATE '1960-01-01' + (random() * 16000)::int,
           TIMESTAMPTZ '2023-01-01' + random() * INTERVAL '1300 days'
    FROM generate_series(1, p_customers) AS i;

    INSERT INTO travel_document (customer_id, document_type, document_number, issuing_country, expiry_date)
    SELECT customer_id, 'PASSPORT', 'A' || lpad(customer_id::text, 8, '0'), 'NG',
           DATE '2027-01-01' + (random() * 3000)::int
    FROM customer;

    INSERT INTO wallet (customer_id, balance)
    SELECT customer_id, round((random() * 500000)::numeric, 2) FROM customer;

    -- Flights between two different airports
    INSERT INTO flight (airline_code, flight_number, origin_iata, destination_iata, departure_time, arrival_time, status)
    SELECT airlines[1 + (i % array_length(airlines, 1))],
           airlines[1 + (i % array_length(airlines, 1))] || (100 + i % 900),
           airports[o],
           airports[1 + ((o - 1 + 1 + (i % (n_airports - 1))) % n_airports)],
           dep,
           dep + (INTERVAL '45 minutes' + random() * INTERVAL '12 hours'),
           CASE WHEN random() < 0.03 THEN 'CANCELLED' WHEN random() < 0.08 THEN 'DELAYED' ELSE 'SCHEDULED' END
    FROM (SELECT i,
                 1 + floor(random() * n_airports)::int AS o,
                 date_trunc('minute', TIMESTAMPTZ '2026-01-01' + random() * INTERVAL '545 days') + (i % 60) * INTERVAL '1 second' AS dep
          FROM generate_series(1, p_flights) AS i) s;

    -- 30 seats per flight: rows 1-2 business, rows 3-10 economy, seats A-C
    INSERT INTO flight_seat (flight_id, seat_number, cabin_class, price)
    SELECT f.flight_id, r || s,
           CASE WHEN r <= 2 THEN 'BUSINESS' ELSE 'ECONOMY' END,
           CASE WHEN r <= 2 THEN 450000 ELSE 95000 END + round((random() * 60000)::numeric, 2)
    FROM flight f, generate_series(1, 10) AS r, unnest(ARRAY['A','B','C']) AS s;

    -- Hotels (3 room types each) and tours
    INSERT INTO hotel (hotel_name, city_id, star_rating, address)
    SELECT 'Hotel ' || i, 1 + (i % (SELECT count(*) FROM city)), 1 + (i % 5), i || ' Marina Road'
    FROM generate_series(1, 300) AS i;

    INSERT INTO room_type (hotel_id, type_name, max_guests, nightly_rate, total_rooms)
    SELECT h.hotel_id, t.name, t.guests, t.base * h.star_rating, 10 + (random() * 40)::int
    FROM hotel h,
         (VALUES ('Standard', 2, 15000), ('Deluxe', 2, 25000), ('Family Suite', 4, 40000)) AS t(name, guests, base);

    INSERT INTO tour (tour_name, city_id, duration_hours, price)
    SELECT 'City Tour ' || i, 1 + (i % (SELECT count(*) FROM city)), 2 + (i % 8), 10000 + (i % 20) * 2500
    FROM generate_series(1, 150) AS i;

    -- Booking headers
    INSERT INTO booking (booking_ref, customer_id, agent_id, status, created_at)
    SELECT 'TN' || upper(lpad(to_hex(i), 6, '0')),   -- unique 8-char reference
           1 + floor(random() * p_customers)::bigint,
           CASE WHEN random() < 0.3 THEN 1 + floor(random() * 4)::int END,
           CASE WHEN r < 0.70 THEN 'CONFIRMED' WHEN r < 0.82 THEN 'COMPLETED'
                WHEN r < 0.92 THEN 'CANCELLED' ELSE 'PENDING' END,
           TIMESTAMPTZ '2025-06-01' + random() * INTERVAL '480 days'
    FROM (SELECT i, random() AS r FROM generate_series(1, p_bookings) AS i) s;

    -- Every booking gets one flight segment on a distinct seat
    CREATE TEMP TABLE tmp_flight_items ON COMMIT DROP AS
    SELECT nextval(pg_get_serial_sequence('tripnest.booking_item', 'item_id')) AS item_id,
           b.booking_id, s.seat_id, s.price, d.document_id
    FROM (SELECT booking_id, customer_id, row_number() OVER (ORDER BY booking_id) AS rn FROM booking) b
    JOIN (SELECT seat_id, price, row_number() OVER (ORDER BY random()) AS rn FROM flight_seat) s ON s.rn = b.rn
    JOIN travel_document d ON d.customer_id = b.customer_id;

    INSERT INTO booking_item (item_id, booking_id, item_type, amount)
    SELECT item_id, booking_id, 'FLIGHT', price FROM tmp_flight_items;
    INSERT INTO flight_booking_item (item_id, seat_id, passenger_document_id)
    SELECT item_id, seat_id, document_id FROM tmp_flight_items;
    UPDATE flight_seat fs SET is_available = FALSE
    FROM tmp_flight_items t WHERE t.seat_id = fs.seat_id;

    -- ~40% of bookings add a hotel stay
    CREATE TEMP TABLE tmp_hotel_items ON COMMIT DROP AS
    SELECT nextval(pg_get_serial_sequence('tripnest.booking_item', 'item_id')) AS item_id,
           b.booking_id, rt.room_type_id, rt.nightly_rate,
           (b.created_at::date + 7 + (random() * 60)::int) AS check_in,
           1 + (random() * 6)::int AS nights
    FROM booking b
    JOIN room_type rt ON rt.room_type_id = 1 + (b.booking_id % (SELECT count(*) FROM room_type))
    WHERE random() < 0.40;

    INSERT INTO booking_item (item_id, booking_id, item_type, amount)
    SELECT item_id, booking_id, 'HOTEL', nightly_rate * nights FROM tmp_hotel_items;
    INSERT INTO hotel_booking_item (item_id, room_type_id, check_in, check_out, rooms, guests)
    SELECT item_id, room_type_id, check_in, check_in + nights, 1, 2 FROM tmp_hotel_items;

    -- ~25% of bookings add a tour
    CREATE TEMP TABLE tmp_tour_items ON COMMIT DROP AS
    SELECT nextval(pg_get_serial_sequence('tripnest.booking_item', 'item_id')) AS item_id,
           b.booking_id, t.tour_id, t.price, b.created_at::date + 10 AS tour_date,
           1 + (random() * 3)::int AS pax
    FROM booking b
    JOIN tour t ON t.tour_id = 1 + (b.booking_id % 150)
    WHERE random() < 0.25;

    INSERT INTO booking_item (item_id, booking_id, item_type, amount)
    SELECT item_id, booking_id, 'TOUR', price * pax FROM tmp_tour_items;
    INSERT INTO tour_booking_item (item_id, tour_id, tour_date, participants)
    SELECT item_id, tour_id, tour_date, pax FROM tmp_tour_items;

    -- One payment per non-pending booking, for the booking total
    INSERT INTO payment (booking_id, amount, method, status, provider_ref, paid_at)
    SELECT b.booking_id, tot.total,
           (ARRAY['CARD','TRANSFER','WALLET','USSD'])[1 + (b.booking_id % 4)],
           CASE b.status WHEN 'CANCELLED' THEN 'REFUNDED' ELSE 'SUCCESS' END,
           'PSP-' || b.booking_id,
           b.created_at + INTERVAL '5 minutes'
    FROM booking b
    JOIN (SELECT booking_id, sum(amount) AS total FROM booking_item GROUP BY booking_id) tot USING (booking_id)
    WHERE b.status <> 'PENDING';

    INSERT INTO refund (payment_id, amount, reason, processed_by, refunded_at)
    SELECT payment_id, amount, 'Customer cancellation', 3, paid_at + INTERVAL '2 days'
    FROM payment WHERE status = 'REFUNDED';
END $$;

CALL seed_bulk(50000, 20000, 200000);

ANALYZE;   -- refresh planner statistics after the bulk load
