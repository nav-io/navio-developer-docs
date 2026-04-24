# REST API reference

All endpoints are documented via the live Swagger UI at `/docs` on any running instance, and auto-generated into this documentation from the API's OpenAPI JSON at `/docs/json` by the nightly build pipeline.

Base URL in production: `https://<your-explorer>/api/…`.

## Endpoint map

| Method | Path                                 | Description                                                       |
| ------ | ------------------------------------ | ----------------------------------------------------------------- |
| GET    | `/api/blocks`                        | Latest blocks (paginated: `limit`, `offset`)                      |
| GET    | `/api/blocks/:hashOrHeight`          | Single block by hash or height                                    |
| GET    | `/api/blocks/:hashOrHeight/txs`      | Transactions in a block                                           |
| GET    | `/api/txs/:txid`                     | Transaction detail with inputs and outputs                         |
| GET    | `/api/search?q=`                     | Search by block hash, height, or txid                              |
| GET    | `/api/stats`                         | Network overview (height, difficulty, BLSCT %, etc.)              |
| GET    | `/api/stats/chart?period=`           | Chart data for block times and tx counts                          |
| GET    | `/api/mempool`                       | Live mempool stats (proxied from naviod)                          |
| GET    | `/api/nodes`                         | Connected peers with geolocation                                  |
| GET    | `/api/nodes/map`                     | Peer data formatted for map visualisation                          |
| GET    | `/api/price`                         | Current NAV price (USD, BTC) + 24h change                          |
| GET    | `/api/price/history?period=`         | Price history (`24h`, `7d`, `30d`, `1y`)                           |
| GET    | `/api/supply`                        | Current supply overview (total, max, burned, reward)              |
| GET    | `/api/supply/chart?period=`          | Supply over time chart data (`24h`, `7d`, `30d`, `1y`, `all`)     |
| GET    | `/api/supply/block/:height`          | Supply data for a specific block                                  |
| GET    | `/api/supply/burned`                 | Burned fees summary (total, 24h, 7d, 30d)                          |
| GET    | `/api/health`                        | Health check                                                      |
| GET    | `/api/tokens`                        | List known token collections                                      |
| GET    | `/api/tokens/:id`                    | Token collection detail                                           |
| GET    | `/api/nfts/:id`                      | NFT detail                                                        |
| GET    | `/api/outputs/:output_hash`          | Single BLSCT output by `output_hash`                              |

!!! info "Auto-generated"
    Once the build pipeline runs, this directory will contain a file per endpoint with full request/response schemas rendered from the OpenAPI JSON. Until then, consult `/docs` on a running instance for live schemas.

## Pagination

Most list endpoints accept:

-   `limit` — number of records, default 20, max 100.
-   `offset` — zero-based offset.

## Response format

All responses are JSON. Error responses have the shape:

```json
{
    "statusCode": 404,
    "error": "Not Found",
    "message": "Block 999999 not found"
}
```

## Privacy-aware fields

Output objects include a `privacy` discriminator:

```json
{
    "output_hash": "abcd...",
    "privacy": "blsct",
    "amount": null,
    "address": null,
    "blsct": {
        "blinding_key": "...",
        "view_tag": 17,
        "spending_key": "..."
    }
}
```

Transparent outputs:

```json
{
    "output_hash": "abcd...",
    "privacy": "transparent",
    "amount": 5000000000,
    "address": "nav1..."
}
```
