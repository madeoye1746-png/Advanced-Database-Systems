# Case Study: TripNest Travel & Booking Platform

## Organisation / scenario

**TripNest** is a simulated Nigerian online travel agency headquartered in Lagos. It sells flights, hotel stays and guided tours through a website, a mobile app and a small team of travel agents. Customers can bundle several services into a single booking. For example, a Lagos–Dubai return flight, four nights in a hotel and a desert tour can all go on one booking reference and one payment.

All names, airlines, customers and documents in this portfolio are simulated. No data from any real organisation is used.

## Nature of the business / system

TripNest is a transactional, read-heavy e-commerce system.

- **Read-heavy:** Customers search flight and hotel availability far more often than they book.
- **Write-critical:** Seat inventory, room inventory and payments must never be oversold or double-charged.
- **Seasonal peaks:** Demand spikes around Christmas, Easter, Sallah and summer travel, which raises the importance of concurrency control and availability.

## Users of the database

| User | How they use the database |
|---|---|
| Customers | Search inventory, create bookings, pay (card, transfer, USSD or wallet), view booking history |
| Travel agents | Create and modify bookings for walk-in or phone customers |
| Supervisors | Approve refunds and handle cancellations |
| Administrators | Manage inventory (flights, seats, hotels, tours) and reference data |
| Finance / management | Revenue, occupancy and sales reports |

## Major data stored

- Customers, their travel documents (passport, national ID, visa) and wallets
- Reference data: countries, cities, airports, airlines
- Inventory: flights and seats, hotels and room types, tours
- Bookings and booking items, covering flight segments, hotel stays and tours
- Payments, refunds and wallet transactions (audit trail)

## Key operations

1. Search flights by route and date; search hotels by city and dates
2. Create a multi-item booking and reserve seats or rooms
3. Pay for a booking, including payment from a wallet balance
4. Cancel a booking and process a refund
5. Retrieve a customer's booking history
6. Produce revenue, load-factor and occupancy reports

## Why this case study fits every portfolio activity

| Portfolio | How TripNest supports it |
|---|---|
| 1. Design | Rich relationships, a supertype/subtype design for booking items, many domain constraints |
| 2. Optimisation | Large tables (600k seats, 200k bookings) and realistic search and reporting queries |
| 3. Transactions | Last-seat race condition, wallet payments that must roll back on failure |
| 4. NoSQL | Itineraries as nested documents (MongoDB); search cache and seat holds with TTL (Redis) |
| 5. Distributed | Read replicas for search traffic; strong vs eventual consistency for inventory vs search |
