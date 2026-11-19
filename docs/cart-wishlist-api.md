# Cart and Wishlist API

All endpoints require a verified user's access token:

```http
Authorization: Bearer <access-token>
Content-Type: application/json
```

Prices are read from the current product documents and are returned in integer
minor units. Cart quantities are bounded from 1 through 99. Items in one cart
must use the same currency.

## Cart

### `GET /api/v1/cart`

Returns the current user's cart. A missing cart is represented as an empty
cart. Each item includes current product details, `available`, and its current
line total. `canCheckout` is false when the cart is empty or a product is
missing, inactive, or has insufficient stock.

```json
{
  "cart": {
    "items": [
      {
        "productId": "507f1f77bcf86cd799439011",
        "quantity": 2,
        "available": true,
        "product": {
          "id": "507f1f77bcf86cd799439011",
          "name": "Desk lamp",
          "slug": "desk-lamp",
          "priceMinor": 2500,
          "currency": "USD",
          "image": {"url": "https://example.test/lamp.png"}
        },
        "lineTotalMinor": 5000
      }
    ],
    "currency": "USD",
    "subtotalMinor": 5000,
    "discountMinor": 0,
    "totalMinor": 5000,
    "coupon": null,
    "canCheckout": true
  }
}
```

### `POST /api/v1/cart/items`

Adds a product or increments the quantity already in the cart. The quantity
field is optional and defaults to `1`.

```json
{"productId": "507f1f77bcf86cd799439011", "quantity": 2}
```

Returns `200 OK` with the updated cart. Inactive/missing products return `404`;
stock conflicts return `409`.

### `PATCH /api/v1/cart/items/{productId}`

Replaces the cart item quantity:

```json
{"quantity": 3}
```

Returns `200 OK` with the updated cart. Quantity and available stock are
validated on the server.

### `DELETE /api/v1/cart/items/{productId}`

Removes one item from the authenticated user's cart and returns the updated
cart. Removing a missing item is idempotent.

### `DELETE /api/v1/cart`

Empties the authenticated user's cart and removes its applied coupon. Returns
the empty cart.

### `POST /api/v1/cart/coupon`

Validates and applies a coupon to the current cart. Codes are trimmed and
normalized to uppercase.

```json
{"code": "SAVE10"}
```

Percent coupons use whole percentages from 1 through 100. Fixed discounts must
match the cart currency. Active dates, minimum subtotal, maximum discount, and
usage limits are checked against the database. Validation failures return
`422 Unprocessable Entity`.

### `DELETE /api/v1/cart/coupon`

Removes the applied coupon and returns the updated cart.

Cart prices and stock are informational until checkout; checkout must re-read
them and validate them again. Applying a coupon does not consume its usage
count. Coupon usage is committed during order creation in the checkout phase.

## Wishlist

### `GET /api/v1/wishlist?page=1&limit=20`

Returns a page of the authenticated user's wishlist, including current product
data and an `available` flag. Removed products remain visible as unavailable
entries until deleted from the wishlist. `limit` is bounded by the shared
pagination contract.

### `POST /api/v1/wishlist`

Adds an active product idempotently; adding the same product repeatedly does
not create duplicates.

```json
{"productId": "507f1f77bcf86cd799439011"}
```

Returns `201 Created` when the product was newly added, or `200 OK` if it was
already present.

### `DELETE /api/v1/wishlist/{productId}`

Removes the product from only the authenticated user's wishlist. Returns
`204 No Content`; removing a missing entry is idempotent.

## Ownership and persistence

Every query and mutation is scoped by the authenticated user's MongoDB `userId`.
Cart data stores product IDs and quantities only, never client-supplied prices.
The unique cart-user index and unique wishlist `(userId, productId)` index
prevent duplicate user records.
