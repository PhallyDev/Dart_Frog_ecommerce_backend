# Bakong KHQR Payments API

All routes require an authenticated ShopEase bearer access token.

## Create payment

`POST /api/v1/payments`

```json
{
  "orderId": "<MongoDB ObjectId>"
}
```

The backend obtains the amount and currency from the stored order; the client
cannot supply or change them.

## Get payment status

`GET /api/v1/payments/{paymentId}`

Returns the payment status, QR payload, expiry, and public payment fields.
Polling this endpoint never marks a payment paid.

## Verify payment

`POST /api/v1/payments/{paymentId}/verify`

The backend calls Bakong by MD5, validates status, amount, currency, merchant
receiver, expiry, and transaction uniqueness, then marks the order paid.

## Cancel pending payment

`DELETE /api/v1/payments/{paymentId}`

Cancels only an owned, pending payment.

## Lifecycle

Payments use `PENDING`, `PAID`, `FAILED`, `EXPIRED`, and `CANCELLED`.

Required environment variables:

- `BAKONG_TOKEN`
- `BAKONG_MERCHANT_ACCOUNT_ID`
- `BAKONG_MERCHANT_NAME`
- `BAKONG_MERCHANT_CITY`
- `BAKONG_BASE_URL` (defaults to the official Bakong host)
- `BAKONG_REQUEST_TIMEOUT_SECONDS`
- `BAKONG_PAYMENT_EXPIRY_MINUTES`
