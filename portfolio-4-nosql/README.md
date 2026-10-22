# Portfolio 4 — NoSQL and Advanced Data Models

> Status: **planned**. Models the same TripNest business in non-relational stores.

## Planned models

### MongoDB (document model) — `mongodb/`
- **`itineraries` collection.** One document per booking, with flights, hotel stays, tours, passengers and payments embedded as arrays. One read returns the whole trip, which is exactly what the "My Trips" screen needs.
- **`traveller_profiles` collection.** Flexible preferences (meal, seat, loyalty numbers) that vary from customer to customer.
- Planned evidence: insert scripts, queries (`find`, aggregation pipeline for revenue by destination), an index, and a comparison with the equivalent SQL join.

### Redis (key-value model) — `redis/`
- **Seat holds:** `SET hold:flight:{id}:seat:{no} {customerId} NX EX 600`. The seat is held for 10 minutes and released automatically if the customer does not pay.
- **Search cache:** cache flight search results by route and date with a short TTL.

## Suitability discussion (to write)

- When a document model fits better than relational, and when it does not (payments and seat inventory stay relational).
- Embedding vs referencing trade-offs.
- Consistency: why Redis seat holds are safe because `NX` makes the hold atomic.

## Running

A `docker-compose.yml` for MongoDB and Redis will be added here.
