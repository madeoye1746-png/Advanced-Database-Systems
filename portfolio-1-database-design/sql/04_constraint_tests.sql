-- =====================================================================
-- TripNest — Constraint tests (evidence for Portfolio 1)
-- Every INSERT/UPDATE below is EXPECTED TO FAIL. Screenshot the errors.
-- Run with:  psql -d tripnest -f 04_constraint_tests.sql
-- =====================================================================
SET search_path TO tripnest;
\echo '--- Test 1: CHECK - flight cannot arrive before it departs'
INSERT INTO flight (airline_code, flight_number, origin_iata, destination_iata, departure_time, arrival_time)
VALUES ('TN', 'TN999', 'LOS', 'ABV', '2026-12-01 10:00', '2026-12-01 09:00');

\echo '--- Test 2: CHECK - origin and destination must differ'
INSERT INTO flight (airline_code, flight_number, origin_iata, destination_iata, departure_time, arrival_time)
VALUES ('TN', 'TN998', 'LOS', 'LOS', '2026-12-01 10:00', '2026-12-01 11:00');

\echo '--- Test 3: FOREIGN KEY - unknown airport code'
INSERT INTO flight (airline_code, flight_number, origin_iata, destination_iata, departure_time, arrival_time)
VALUES ('TN', 'TN997', 'XXX', 'ABV', '2026-12-01 10:00', '2026-12-01 11:00');

\echo '--- Test 4: UNIQUE - customer email must be unique'
INSERT INTO customer (first_name, last_name, email) VALUES ('Dup', 'User', 'customer1@mail.test');

\echo '--- Test 5: UNIQUE - the same seat cannot be sold twice'
INSERT INTO booking_item (booking_id, item_type, amount) VALUES (1, 'FLIGHT', 100000);
INSERT INTO flight_booking_item (item_id, seat_id, passenger_document_id)
SELECT currval(pg_get_serial_sequence('tripnest.booking_item','item_id')),
       (SELECT seat_id FROM flight_booking_item LIMIT 1), 1;

\echo '--- Test 6: CHECK - wallet balance cannot go negative'
UPDATE wallet SET balance = -1 WHERE wallet_id = 1;

\echo '--- Test 7: CHECK - hotel check-out must be after check-in'
INSERT INTO hotel_booking_item (item_id, room_type_id, check_in, check_out, guests)
VALUES (currval(pg_get_serial_sequence('tripnest.booking_item','item_id')), 1, '2026-12-10', '2026-12-08', 2);

\echo '--- Test 8: CHECK - invalid booking status value'
UPDATE booking SET status = 'LOST' WHERE booking_id = 1;

-- Clean up the orphan header line created in Test 5
DELETE FROM booking_item
WHERE item_id = currval(pg_get_serial_sequence('tripnest.booking_item','item_id'));

\echo '--- Integrity check: every booking item has exactly one matching subtype row (expect 0)'
SELECT count(*) AS items_without_subtype
FROM booking_item bi
WHERE NOT EXISTS (SELECT 1 FROM flight_booking_item f WHERE f.item_id = bi.item_id)
  AND NOT EXISTS (SELECT 1 FROM hotel_booking_item  h WHERE h.item_id = bi.item_id)
  AND NOT EXISTS (SELECT 1 FROM tour_booking_item   t WHERE t.item_id = bi.item_id);

\echo '--- Integrity check: sold seats are marked unavailable (expect 0)'
SELECT count(*) AS sold_but_available
FROM flight_booking_item fbi JOIN flight_seat fs USING (seat_id)
WHERE fs.is_available;
