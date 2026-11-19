# Product and category API

All endpoints are under `/api/v1` and return JSON. Catalog endpoints are public
and read-only in this phase. Product IDs in path parameters are 24-character
MongoDB ObjectId hex strings. Unsupported or repeated query parameters return
`400`; malformed IDs return `400`; missing or inactive products return `404`.

## Categories

### `GET /api/v1/categories`

Lists active categories ordered by `sortOrder`, then name.

| Query | Default | Bounds |
|---|---:|---|
| `page` | `1` | 1–100000 |
| `limit` | `20` | 1–100 |

Example response:

```json
{
  "data": [
    {
      "id": "507f1f77bcf86cd799439011",
      "name": "Lighting",
      "slug": "lighting",
      "sortOrder": 1
    }
  ],
  "pagination": {"page": 1, "limit": 20, "total": 1, "totalPages": 1}
}
```

## Products

### `GET /api/v1/products`

Lists active products. Filters are combined on the server and only values
defined in the following table are accepted.

| Query | Behavior |
|---|---|
| `q` | MongoDB text search over product name and description (maximum 100 characters); defaults to relevance sort |
| `category` | Exact active category slug |
| `minPrice`, `maxPrice` | Inclusive price bounds in major units, with up to two decimals (for example `12.50` becomes 1250 minor units) |
| `inStock` | `true` to require positive stock, or `false` to disable this filter |
| `sort` | `relevance`, `price_asc`, `price_desc`, `name_asc`, `newest`, or `rating_desc` |
| `page` | One-based page; defaults to `1`, maximum `100000` |
| `limit` | Page size; defaults to `20`, maximum `100` |

Without `q`, the default sort is `newest`. `sort=relevance` requires a
non-empty `q`. `rating_desc` sorts on the product's denormalized
`averageRating` field where populated.

Example:

```http
GET /api/v1/products?q=lamp&category=lighting&sort=price_asc&page=1&limit=20
```

Example response:

```json
{
  "data": [
    {
      "id": "507f1f77bcf86cd799439011",
      "name": "Desk lamp",
      "slug": "desk-lamp",
      "description": "Adjustable LED desk lamp.",
      "categoryId": "507f1f77bcf86cd799439012",
      "priceMinor": 4599,
      "currency": "USD",
      "stock": 12,
      "images": [
        {"url": "https://cdn.example.test/desk-lamp.png", "sortOrder": 0}
      ]
    }
  ],
  "pagination": {"page": 1, "limit": 20, "total": 1, "totalPages": 1}
}
```

### `GET /api/v1/products/{id}`

Returns an active product with its image metadata and public catalog fields.

### `GET /api/v1/products/{id}/images`

Returns the product's image metadata:

```json
{
  "productId": "507f1f77bcf86cd799439011",
  "images": [{"url": "https://cdn.example.test/desk-lamp.png", "sortOrder": 0}]
}
```

Image bytes are hosted separately; this endpoint returns stored image URLs and
alt/order metadata, not binary content.

### `GET /api/v1/products/{id}/reviews`

Returns public review fields for an active product, newest first. Supports the
same bounded `page` and `limit` parameters as categories. User IDs and other
internal review fields are not included in the response.

## Running locally

Configure `.env`, then run `dart_frog dev`. The first category or product
request opens the shared MongoDB connection and ensures the application
indexes. The product-list example can then be called with `curl.exe`:

```powershell
curl.exe "http://localhost:8080/api/v1/products?q=lamp&category=lighting&sort=price_asc&page=1&limit=20"
curl.exe "http://localhost:8080/api/v1/categories?page=1&limit=20"
```
