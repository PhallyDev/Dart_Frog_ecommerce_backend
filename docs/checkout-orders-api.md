# Addresses, Shipping, and Checkout API

Address, checkout, and order-creation routes require a verified user's access
token:

```http
Authorization: Bearer <access-token>
Content-Type: application/json
```

## Delivery addresses

### `GET /api/v1/addresses?page=1&limit=20`

Returns paginated addresses belonging only to the authenticated user. Default
addresses are listed first.

### `POST /api/v1/addresses`

Creates an address. Required fields: `recipientName`, `line1`, `city`,
`postalCode`, `countryCode` (ISO 3166-1 alpha-2). Optional fields: `line2`,
`region`, `phone`, and boolean `isDefault`.

```json
{
  "recipientName": "ShopEase Customer",
  "line1": "123 Example Street",
  "city": "Phnom Penh",
  "postalCode": "12000",
  "countryCode": "KH",
  "phone": "+85512345678",
  "isDefault": true
}
```

Returns `201 Created` with the stored address.

### `PUT /api/v1/addresses/{addressId}`

Replaces the address fields using the same schema as creation. Only the
authenticated user's address can be updated.

### `DELETE /api/v1/addresses/{addressId}`

Deletes only an address owned by the authenticated user. Returns `204 No
Content`.

### `PUT /api/v1/addresses/{addressId}/default`

Marks an owned address as default and clears the previous default for that
user.

## Shipping methods

### `GET /api/v1/shipping-methods?page=1&limit=20`

Publicly lists active shipping methods, sorted by price and code. Response
includes the method code, current price in minor currency units, currency, and
delivery-day estimate.

## Checkout preview

### `POST /api/v1/checkout/preview`

Builds a non-reserving quote after re-reading the authenticated user's cart,
delivery address, active shipping method, current product prices and stock,
and any applied coupon.

```json
{
  "addressId": "507f1f77bcf86cd799439011",
  "shippingMethodCode": "standard"
}
```

Response:

```json
{
  "checkout": {
    "items": [
      {
        "productId": "507f1f77bcf86cd799439012",
        "name": "Desk lamp",
        "quantity": 2,
        "unitPriceMinor": 2500,
        "currency": "USD"
      }
    ],
    "address": {
      "addressId": "507f1f77bcf86cd799439011",
      "recipientName": "ShopEase Customer",
      "line1": "123 Example Street",
      "city": "Phnom Penh",
      "postalCode": "12000",
      "countryCode": "KH"
    },
    "shipping": {
      "code": "standard",
      "name": "Standard delivery",
      "priceMinor": 750,
      "currency": "USD",
      "minimumDeliveryDays": 3,
      "maximumDeliveryDays": 5
    },
    "subtotalMinor": 5000,
    "discountMinor": 0,
    "shippingMinor": 750,
    "totalMinor": 5750,
    "currency": "USD"
  }
}
```

The preview does not reserve stock or coupon usage. Prices and availability
must be revalidated when creating the order.

## Create an order

### `POST /api/v1/checkout/orders`

Requires the same JSON body as preview and an `Idempotency-Key` header
(8–128 ASCII letters, digits, `.`, `_`, `:` or `-`):

```http
Idempotency-Key: checkout-2026-unique-001
```

On first success, returns `201 Created` with an order snapshot and
`"replayed": false`. Repeating the same key and checkout inputs returns the
existing order with `200 OK` and `"replayed": true`. Reusing a key with a
different address or shipping method returns `409 Conflict`.

The order stores immutable item name, SKU, price, quantity, address, and
shipping snapshots. Stock is conditionally decremented only while the product
is active, its reviewed price and currency are unchanged, and sufficient stock
remains. Coupon usage is reserved atomically only while the coupon remains
active, within its usage limit, and its discount terms still match the quote.
The cart is cleared only if its contents still match the cart snapshot used to
create the order.
New orders start in `processing` and are ready for fulfillment.

## Consistency and deployment

The installed `mongo_dart` 0.10.10 driver does not expose MongoDB client
sessions or multi-document transaction support. The current checkout therefore
uses conditional atomic single-document inventory/coupon updates, a unique
per-user idempotency index, and compensating stock/coupon updates if a later
reservation or order insert fails. These compensations are not equivalent to a
transaction if the process or database fails during compensation. Production
checkout should move to a transaction-capable driver and run against a replica
set or sharded cluster before claiming transaction-level atomicity.

Customer cancellation records a pending reservation-release state and uses
per-order markers on product and coupon documents. Retrying cancellation after
a partial failure does not repeat completed inventory or coupon releases.
These durable marker arrays grow over time; monitor orders with pending
releases and use a transaction-capable driver for production-scale workflows.

The order idempotency index is scoped by `(userId, idempotencyKey)`. If a
database was initialized with an earlier global `idempotencyKey` unique index
named `orders_idempotency_key_unique`, remove that legacy index during a
controlled migration before enabling the compound index.
