# MongoDB collection contracts

All documents use MongoDB `ObjectId` values for `_id` and for references.
Dates are stored as BSON dates in UTC. Monetary amounts use integer minor units
(for example, cents) together with an ISO 4217 currency code; they must not be
stored as floating-point values. Unless marked optional, fields below are
required. Application services validate these rules before writes; unique and
query indexes are installed by `MongoIndexes.ensureCreated`.

| Collection | Document fields and validation | References / embedded values | Indexes |
|---|---|---|---|
| `users` | `email` (string, required, trimmed/lowercase), `passwordHash` (string, required), `displayName` (string, required), `phone` (string, optional), `emailVerified` (boolean, required), `credentialVersion` (non-negative integer), `verificationTokenHash` / `verificationTokenExpiresAt` (optional), `passwordResetTokenHash` / `passwordResetExpiresAt` (optional), `createdAt` / `updatedAt` (dates, required). Never store plaintext passwords or raw reset/verification tokens. | User-owned records refer to `users._id`. | Unique `email`. |
| `user_sessions` | `_id` (ObjectId, JWT session ID), `userId` (ObjectId), `createdAt`, `expiresAt` (dates), `revokedAt` (date or null). Access JWTs expire after 15 minutes; each request checks this revocable session record. | References `users._id`. | `(userId, revokedAt, expiresAt)`. |
| `categories` | `name` and `slug` (strings, required; slug unique), `description` / `imageUrl` (strings, optional), `parentId` (ObjectId, optional), `sortOrder` (integer, required), `isActive` (boolean, required), `createdAt` / `updatedAt` (dates). | `parentId` references another category. | Unique `slug`; product browsing is indexed through product `categoryId`. |
| `products` | `name`, `slug`, `description` (strings, required), `categoryId` (ObjectId, required), `priceMinor` (non-negative integer), `currency` (ISO 4217 string), `stock` (non-negative integer), `isActive` (boolean), `images` (array of `{url, alt?, sortOrder}`), `cancellationReleaseOrderIds?` (array of ObjectIds, cancellation idempotency markers), `createdAt` / `updatedAt` (dates). | `categoryId` references `categories._id`; images are embedded metadata, not binary payloads. | Unique `slug`; compound `categoryId`, `isActive`, `priceMinor`; text index on `name` and `description`. |
| `reviews` | `productId` / `userId` (ObjectIds, required), `rating` (integer 1–5), `title` / `body` (strings, validated length), `createdAt` / `updatedAt` (dates). | References `products._id` and `users._id`. | Unique `(productId, userId)`; `(productId, createdAt desc)`. |
| `carts` | `userId` (ObjectId, required), `items` (array of `{productId, quantity, addedAt}`; quantity is a positive integer from 1 to 99), `couponCode` (string, optional), `updatedAt` (date). Prices are re-read from products and are not trusted from the client. All items in a cart use one currency. | Items refer to products; coupon code refers to `coupons.code`. | Unique `userId`. |
| `coupons` | `code` (string, required, normalized uppercase), `kind` (`percent` or `fixed`), `value` (positive integer; whole percent from 1 to 100 for `percent`), `minimumSubtotalMinor` / `maximumDiscountMinor` (non-negative integers, optional), `currency` (required for fixed discounts), `startsAt` / `expiresAt` (dates, optional), `usageLimit` (positive integer, optional), `usageCount` (non-negative integer), `isActive` (boolean), `cancellationReleaseOrderIds?` (array of ObjectIds, cancellation idempotency markers), `createdAt` / `updatedAt` (dates). | Redemption/order references are recorded on orders; usage updates must be atomic. Cart validation does not consume usage; checkout will atomically increment usage when placing an order. | Unique `code`. |
| `addresses` | `userId` (ObjectId), `recipientName`, `line1`, `city`, `postalCode`, `countryCode` (strings, required), `line2`, `region`, `phone` (strings, optional), `isDefault` (boolean), `createdAt` / `updatedAt` (dates). Country code is ISO 3166-1 alpha-2. | References `users._id`. | `(userId, isDefault desc)`. |
| `shipping_methods` | `code`, `name` (strings), `priceMinor` (non-negative integer), `currency` (ISO 4217), `minimumDeliveryDays` / `maximumDeliveryDays` (positive integers, minimum no greater than maximum), `isActive` (boolean), `createdAt` / `updatedAt` (dates). | Selected order stores a snapshot of method name, code, price, and delivery estimate. | Unique `code`. |
| `orders` | `userId` (ObjectId), `orderNumber` (string), `idempotencyKey` (string), `requestFingerprint` (SHA-256 of checkout address/method inputs), `status` (processing/shipped/in_transit/delivered/cancelled), `reservationReleaseState?` (pending/complete), `reservationsReleased?` (boolean), `items` (non-empty array of `{productId, name, sku?, quantity, unitPriceMinor, currency, imageUrl?}`), `addressSnapshot` and `shippingSnapshot` (required embedded snapshots), `subtotalMinor`, `discountMinor`, `shippingMinor`, `totalMinor` (non-negative integer amounts), `currency`, `couponCode?`, `createdAt` / `updatedAt` (dates). Snapshot prices/names are immutable after order placement. | References user; product IDs in items are historical references, not a source for historical display values. Address/shipping snapshots are embedded. | Unique `orderNumber`; unique `(userId, idempotencyKey)`; `(userId, createdAt desc)`; `(status, createdAt desc)`. |
| `order_tracking_events` | `orderId` / `userId` (ObjectIds), `status` (validated fulfillment state), `message` (string), `location?` (string), `occurredAt` (date), `createdAt` (date). | References order/user. | `(orderId, createdAt asc)`. |
| `wishlists` | `userId` / `productId` (ObjectIds), `addedAt` (date). One document represents one user-product pair. | References users and products. | Unique `(userId, productId)` prevents duplicate entries. |
| `user_settings` | `userId` (ObjectId), `theme` (`light`, `dark`, or `system`), `preferences` (optional validated object), `createdAt` / `updatedAt` (dates). | References `users._id`; a missing settings document defaults to the `system` theme until the first update. | Unique `userId`. |

## Consistency notes

- Normalize email addresses and coupon codes before writes; unique indexes are
  the final defense against concurrent duplicates.
- Update stock using conditional atomic updates (`stock >= requested quantity`)
  and only decrement when the matched document count confirms availability.
- MongoDB `mongo_dart` 0.10.10 in this project does not expose client sessions
  for multi-document transactions. Checkout uses conditional atomic inventory
  and coupon updates, unique order idempotency, and compensating updates on
  failure; a process or database failure during compensation can still leave
  reservations inconsistent. Use a transaction-capable driver on a replica set
  or sharded cluster before claiming transaction-level atomicity.
- Use a unique order idempotency key so repeated checkout requests return the
  existing order rather than creating another. Cancellation writes a pending
  release state before changing inventory/coupon documents. Per-order markers
  on products and coupons make those individual releases retry-safe; marker
  arrays are durable and grow over time. Fulfillment status/tracking-event writes
  span multiple documents and
  require operational reconciliation if the process stops between writes.

Older deployments that already created the global unique index named
`orders_idempotency_key_unique` must drop it during a controlled migration
before the compound per-user idempotency index is installed.

