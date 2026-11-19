# Profile and settings API

All endpoints use the `/api/v1` prefix and require a valid bearer access token.
Requests with a body must use `Content-Type: application/json`.

## Get profile

`GET /api/v1/profile`

Returns the caller's public profile. Password hashes, credential versions, and
authentication tokens are never included.

```json
{
  "user": {
    "id": "665f1a2b3c4d5e6f708192a3",
    "email": "customer@example.test",
    "displayName": "Alex Example",
    "emailVerified": true,
    "phone": "+1 (555) 123-4567"
  }
}
```

## Update profile

`PATCH /api/v1/profile`

Only `displayName` and `phone` may be changed. At least one supported field is
required. `displayName` must contain 2–80 characters after trimming. A phone
number may be set to `null` to remove it; otherwise it must contain 5–32
characters in an international phone-number format. Email changes are not
accepted through this endpoint.

```json
{
  "displayName": "Alex Example",
  "phone": "+1 (555) 123-4567"
}
```

Returns the updated profile using the same response shape as `GET /profile`.
Unknown fields and invalid values receive a `400` response.

## Get settings

`GET /api/v1/settings`

Returns stored settings. Users without a settings document receive the default
`system` theme without requiring a database write.

```json
{
  "settings": {
    "theme": "system"
  }
}
```

## Update theme preference

`PUT /api/v1/settings`

Persists one of the supported theme preferences:

```json
{
  "theme": "dark"
}
```

`theme` must be `light`, `dark`, or `system`. Other fields or values receive a
`400` response. The settings document is created on the first update and is
uniquely keyed by the authenticated user's ID.
