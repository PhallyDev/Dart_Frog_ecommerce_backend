# Authentication API

All endpoints are under `/api/v1/auth`. JSON write endpoints require
`Content-Type: application/json`. Passwords must be 12–128 characters.
Email addresses are normalized to lowercase. Tokens are sent only by email or
in the successful login response; one-time verification and reset tokens are
stored as SHA-256 hashes and expire after 30 and 20 minutes respectively.

## Endpoints

### `POST /api/v1/auth/register` and `POST /api/v1/auth/signup`

Both routes use the same registration handler. `/register` is the canonical
alias; `/signup` remains available for existing clients. Request:

```json
{
  "email": "customer@example.test",
  "password": "a-long-example-password",
  "displayName": "ShopEase Customer"
}
```

Returns `201 Created` with a public user profile and a request to check email.
The verification token is never returned by the API. Configure SMTP before
sign-up; if delivery fails, the unverified account remains and can request a
new message using `/resend-verification`.

### `POST /api/v1/auth/verify-email`

Request: `{"token":"<token-from-email>"}`. Returns the public user profile when
the single-use token is valid. Invalid, expired, and already-used tokens return
the same error.

### `POST /api/v1/auth/resend-verification`

Request: `{"email":"customer@example.test"}`. Returns `202 Accepted` with a
generic response whether or not an unverified account exists.

### `POST /api/v1/auth/login`

Request: `{"email":"customer@example.test","password":"a-long-example-password"}`.
Requires a verified account. Returns a signed HS256 Bearer JWT, its 900-second
expiry, and a public profile. Invalid credentials and unverified accounts share
the same `401` response.

Successful login returns the standard envelope while retaining the original
top-level fields for existing clients:

```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "<signed-access-token>",
    "tokenType": "Bearer",
    "expiresIn": 900,
    "user": {
      "id": "507f1f77bcf86cd799439011",
      "name": "ShopEase Customer",
      "email": "customer@example.test",
      "displayName": "ShopEase Customer",
      "emailVerified": true
    }
  }
}
```

### `GET /api/v1/auth/me`

Requires `Authorization: Bearer <access-token>`. Returns only the authenticated
user's public profile.

### `POST /api/v1/auth/logout`

Requires `Authorization: Bearer <access-token>`. Revokes only that user's
current session; other sessions remain untouched. Returns `204 No Content`.

### `POST /api/v1/auth/forgot-password`

Request: `{"email":"customer@example.test"}`. Returns `202 Accepted` with the
same response for existing and non-existing accounts.

### `POST /api/v1/auth/reset-password`

Request: `{"token":"<token-from-email>","password":"a-new-long-password"}`.
Consumes the one-time token, updates the Argon2id password hash, increments the
user credential version, and revokes existing sessions.

## Security and operations

- Passwords use Argon2id with 19 MiB memory, two iterations, one lane, and a
  unique 128-bit cryptographically random salt.
-   JWTs are HS256 signed, audience/issuer restricted, and expire after 15
  minutes by default. `JWT_ACCESS_TOKEN_TTL_MINUTES` can set a lifetime from
  1 to 60 minutes. Every protected request also checks the `user_sessions` record and
  the user's credential version. Logout revokes one session; password reset
  increments the credential version atomically before revoking stored sessions.
- Auth routes have per-IP fixed-window limits over 15 minutes: login 10,
  signup 5, forgot/reset 5, verification 10, and other auth routes 30. The
  limiter is in-process; production deployments with multiple workers should
  also enforce shared rate limits at an API gateway or shared store.
- Set a unique `JWT_SECRET` of at least 32 characters. SMTP is optional for
  non-email routes, but signup/recovery delivery returns `503` until SMTP host,
  username, password, sender, and port are configured. Port 587 uses STARTTLS;
  port 465 uses TLS. Production `PUBLIC_API_BASE_URL` must use HTTPS.
- No refresh token is issued; clients sign in again after the short-lived
  access token expires. No raw password, verification token, reset token, or
  SMTP credential is included in API responses or logs.

To generate a JWT secret in PowerShell:

```powershell
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 32
$rng.GetBytes($bytes)
[BitConverter]::ToString($bytes).Replace('-', '').ToLower()
```
