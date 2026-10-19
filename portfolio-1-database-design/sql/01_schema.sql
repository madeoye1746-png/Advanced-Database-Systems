-- =====================================================================
-- TripNest Travel & Booking Platform — Relational Schema (PostgreSQL 16)
-- MIT 8103 Advanced Database Systems — Portfolio 1
-- Normal form target: 3NF (BCNF for all tables except where noted)
-- =====================================================================

DROP SCHEMA IF EXISTS tripnest CASCADE;
CREATE SCHEMA tripnest;
SET search_path TO tripnest;

-- ---------------------------------------------------------------------
-- Reference / lookup data
-- ---------------------------------------------------------------------
CREATE TABLE country (
    country_code  CHAR(2)      PRIMARY KEY,               -- ISO 3166-1 alpha-2
    country_name  VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE city (
    city_id       SERIAL       PRIMARY KEY,
    city_name     VARCHAR(100) NOT NULL,
    country_code  CHAR(2)      NOT NULL REFERENCES country(country_code),
    UNIQUE (city_name, country_code)
);

CREATE TABLE airport (
    iata_code     CHAR(3)      PRIMARY KEY,
    airport_name  VARCHAR(150) NOT NULL,
    city_id       INT          NOT NULL REFERENCES city(city_id)
);

CREATE TABLE airline (
    airline_code  CHAR(2)      PRIMARY KEY,               -- IATA airline designator
    airline_name  VARCHAR(100) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- Users of the system
-- ---------------------------------------------------------------------
CREATE TABLE customer (
    customer_id   BIGSERIAL    PRIMARY KEY,
    first_name    VARCHAR(60)  NOT NULL,
    last_name     VARCHAR(60)  NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(20),
    date_of_birth DATE         CHECK (date_of_birth < CURRENT_DATE),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE agent (                                       -- staff / travel agents
    agent_id      SERIAL       PRIMARY KEY,
    full_name     VARCHAR(120) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    role          VARCHAR(20)  NOT NULL CHECK (role IN ('AGENT','SUPERVISOR','ADMIN'))
);

CREATE TABLE travel_document (
    document_id     BIGSERIAL   PRIMARY KEY,
    customer_id     BIGINT      NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
    document_type   VARCHAR(20) NOT NULL CHECK (document_type IN ('PASSPORT','NATIONAL_ID','VISA')),
    document_number VARCHAR(30) NOT NULL,                  -- simulated data only
    issuing_country CHAR(2)     NOT NULL REFERENCES country(country_code),
    expiry_date     DATE        NOT NULL,
    UNIQUE (document_type, document_number, issuing_country)
);

-- Wallet: one per customer, used in Portfolio 3 transaction demos
CREATE TABLE wallet (
    wallet_id     BIGSERIAL     PRIMARY KEY,
    customer_id   BIGINT        NOT NULL UNIQUE REFERENCES customer(customer_id) ON DELETE CASCADE,
    balance       NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    version       INT           NOT NULL DEFAULT 0          -- optimistic locking (Portfolio 3)
);

-- ---------------------------------------------------------------------
-- Flights
-- ---------------------------------------------------------------------
CREATE TABLE flight (
    flight_id          BIGSERIAL    PRIMARY KEY,
    airline_code       CHAR(2)      NOT NULL REFERENCES airline(airline_code),
    flight_number      VARCHAR(8)   NOT NULL,
    origin_iata        CHAR(3)      NOT NULL REFERENCES airport(iata_code),
    destination_iata   CHAR(3)      NOT NULL REFERENCES airport(iata_code),
    departure_time     TIMESTAMPTZ  NOT NULL,
    arrival_time       TIMESTAMPTZ  NOT NULL,
    status             VARCHAR(12)  NOT NULL DEFAULT 'SCHEDULED'
                       CHECK (status IN ('SCHEDULED','DELAYED','CANCELLED','DEPARTED','ARRIVED')),
    CHECK (origin_iata <> destination_iata),
    CHECK (arrival_time > departure_time),
    UNIQUE (airline_code, flight_number, departure_time)
);

CREATE TABLE flight_seat (
    seat_id       BIGSERIAL     PRIMARY KEY,
    flight_id     BIGINT        NOT NULL REFERENCES flight(flight_id) ON DELETE CASCADE,
    seat_number   VARCHAR(4)    NOT NULL,
    cabin_class   VARCHAR(10)   NOT NULL CHECK (cabin_class IN ('ECONOMY','PREMIUM','BUSINESS','FIRST')),
    price         NUMERIC(12,2) NOT NULL CHECK (price > 0),
    is_available  BOOLEAN       NOT NULL DEFAULT TRUE,
    version       INT           NOT NULL DEFAULT 0,          -- optimistic locking (Portfolio 3)
    UNIQUE (flight_id, seat_number)
);

-- ---------------------------------------------------------------------
-- Hotels
-- ---------------------------------------------------------------------
CREATE TABLE hotel (
    hotel_id      SERIAL       PRIMARY KEY,
    hotel_name    VARCHAR(150) NOT NULL,
    city_id       INT          NOT NULL REFERENCES city(city_id),
    star_rating   SMALLINT     CHECK (star_rating BETWEEN 1 AND 5),
    address       VARCHAR(250)
);

CREATE TABLE room_type (
    room_type_id   SERIAL        PRIMARY KEY,
    hotel_id       INT           NOT NULL REFERENCES hotel(hotel_id) ON DELETE CASCADE,
    type_name      VARCHAR(50)   NOT NULL,
    max_guests     SMALLINT      NOT NULL CHECK (max_guests > 0),
    nightly_rate   NUMERIC(12,2) NOT NULL CHECK (nightly_rate > 0),
    total_rooms    INT           NOT NULL CHECK (total_rooms >= 0),
    UNIQUE (hotel_id, type_name)
);

-- ---------------------------------------------------------------------
-- Tours
-- ---------------------------------------------------------------------
CREATE TABLE tour (
    tour_id        SERIAL        PRIMARY KEY,
    tour_name      VARCHAR(150)  NOT NULL,
    city_id        INT           NOT NULL REFERENCES city(city_id),
    duration_hours NUMERIC(4,1)  NOT NULL CHECK (duration_hours > 0),
    price          NUMERIC(12,2) NOT NULL CHECK (price > 0)
);

-- ---------------------------------------------------------------------
-- Bookings (header) and booking items (lines)
-- One booking can bundle flights, hotel stays and tours.
-- ---------------------------------------------------------------------
CREATE TABLE booking (
    booking_id      BIGSERIAL     PRIMARY KEY,
    booking_ref     CHAR(8)       NOT NULL UNIQUE,         -- customer-facing PNR-style reference
    customer_id     BIGINT        NOT NULL REFERENCES customer(customer_id),
    agent_id        INT           REFERENCES agent(agent_id), -- NULL = self-service booking
    status          VARCHAR(12)   NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING','CONFIRMED','CANCELLED','COMPLETED')),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Supertype for every line on a booking
CREATE TABLE booking_item (
    item_id       BIGSERIAL     PRIMARY KEY,
    booking_id    BIGINT        NOT NULL REFERENCES booking(booking_id) ON DELETE CASCADE,
    item_type     VARCHAR(6)    NOT NULL CHECK (item_type IN ('FLIGHT','HOTEL','TOUR')),
    amount        NUMERIC(12,2) NOT NULL CHECK (amount >= 0)
);

-- Subtype: flight segment (one passenger in one seat)
CREATE TABLE flight_booking_item (
    item_id       BIGINT       PRIMARY KEY REFERENCES booking_item(item_id) ON DELETE CASCADE,
    seat_id       BIGINT       NOT NULL UNIQUE REFERENCES flight_seat(seat_id), -- a seat can only be sold once
    passenger_document_id BIGINT NOT NULL REFERENCES travel_document(document_id)
);

-- Subtype: hotel stay
CREATE TABLE hotel_booking_item (
    item_id       BIGINT       PRIMARY KEY REFERENCES booking_item(item_id) ON DELETE CASCADE,
    room_type_id  INT          NOT NULL REFERENCES room_type(room_type_id),
    check_in      DATE         NOT NULL,
    check_out     DATE         NOT NULL,
    rooms         SMALLINT     NOT NULL DEFAULT 1 CHECK (rooms > 0),
    guests        SMALLINT     NOT NULL CHECK (guests > 0),
    CHECK (check_out > check_in)
);

-- Subtype: tour
CREATE TABLE tour_booking_item (
    item_id       BIGINT       PRIMARY KEY REFERENCES booking_item(item_id) ON DELETE CASCADE,
    tour_id       INT          NOT NULL REFERENCES tour(tour_id),
    tour_date     DATE         NOT NULL,
    participants  SMALLINT     NOT NULL CHECK (participants > 0)
);

-- ---------------------------------------------------------------------
-- Payments and refunds
-- ---------------------------------------------------------------------
CREATE TABLE payment (
    payment_id     BIGSERIAL     PRIMARY KEY,
    booking_id     BIGINT        NOT NULL REFERENCES booking(booking_id),
    amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    method         VARCHAR(12)   NOT NULL CHECK (method IN ('CARD','TRANSFER','WALLET','USSD')),
    status         VARCHAR(10)   NOT NULL CHECK (status IN ('PENDING','SUCCESS','FAILED','REFUNDED')),
    provider_ref   VARCHAR(50)   UNIQUE,
    paid_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE refund (
    refund_id      BIGSERIAL     PRIMARY KEY,
    payment_id     BIGINT        NOT NULL REFERENCES payment(payment_id),
    amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reason         VARCHAR(250),
    processed_by   INT           REFERENCES agent(agent_id),
    refunded_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Audit trail for wallet movements (used in Portfolio 3)
CREATE TABLE wallet_transaction (
    txn_id        BIGSERIAL     PRIMARY KEY,
    wallet_id     BIGINT        NOT NULL REFERENCES wallet(wallet_id),
    txn_type      VARCHAR(10)   NOT NULL CHECK (txn_type IN ('CREDIT','DEBIT')),
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    booking_id    BIGINT        REFERENCES booking(booking_id),
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Only primary/unique keys are indexed at this stage.
-- Secondary indexes are deliberately added in Portfolio 2 so that
-- before/after execution plans can be compared.
