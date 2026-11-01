# REST API reference

All endpoints are documented via the live Swagger UI at `/docs` on any running instance, and auto-generated into this documentation from the API's OpenAPI JSON at `/docs/json` by the nightly build pipeline.

Base URL in production: `https://<your-explorer>/api/…` for mainnet and `https://<your-explorer>/api/testnet/…` for testnet. Every route below is mounted under both prefixes; `/api/health` exists once.

## Endpoint map

| Method | Path                                 | Description                                                       |
| ------ | ------------------------------------ | ----------------------------------------------------------------- |
| GET    | `/api/blocks`                        | Latest blocks (paginated: `limit`, `offset`)                      |
| GET    | `/api/blocks/:hashOrHeight`          | Single block by hash or height                                    |
| GET    | `/api/blocks/:hashOrHeight/txs`      | Transactions in a block                                           |
| GET    | `/api/txs/:txidOrOutput`             | Transaction detail with inputs and outputs                         |
| GET    | `/api/outputs`                       | Outputs with `type`, `token_mode` (`nav` / `tokens` / `nfts`) and `spent` filters |
| GET    | `/api/outputs/:hash`                 | Single output by `output_hash`; carries `delegated` for cold-staked outputs |
| GET    | `/api/outputs/stats`                 | Output type distribution, optional timeframe                       |
| GET    | `/api/outputs/timeline?period=`      | New outputs per time bucket, split coinbase / fee / user           |
| GET    | `/api/search?q=`                     | Search for a block, transaction, output, collection or NFT         |
| GET    | `/api/stats`                         | Network overview (height, difficulty, BLSCT %, etc.)              |
| GET    | `/api/stats/chart?period=`           | Block spacing, difficulty and transaction-count chart data         |
| GET    | `/api/mempool`                       | Live mempool stats (proxied from naviod)                          |
| GET    | `/api/nodes`                         | Peers seen in the last 7 days, with country / version aggregations and decoded service flags |
| GET    | `/api/nodes/map`                     | Peer data formatted for map visualisation                          |
| GET    | `/api/nodes/history?period=`         | Total, listening and active (3 h) node counts over time            |
| GET    | `/api/staking`                       | Staking overview: active stakes, total staked, age distribution    |
| GET    | `/api/staking/summary`               | Active / delegated commitments, lifetime and 24 h activity, node-side staked set |
| GET    | `/api/staking/history?period=`       | Unspent staked-commitment count over time, total and delegated     |
| GET    | `/api/staking/activity?period=`      | Staked commitments created (total / delegated) and spent per bucket |
| GET    | `/api/staking/commitments`           | Staked commitments, newest first (`status` = `active` / `spent` / `all`, `delegated` = `0` / `1`) |
| GET    | `/api/p2pmsg/summary`                | Latest p2pmsg overlay snapshot with relay-capable % and 24 h trend |
| GET    | `/api/p2pmsg/history?period=`        | Historical overlay stats                                           |
| GET    | `/api/p2pmsg/trading`                | Aggregate RFQ / standing-order counts (individual orders stay private) |
| GET    | `/api/price`                         | Current NAV price + 24h change                                     |
| GET    | `/api/price/history?period=`         | Price history                                                      |
| GET    | `/api/supply`                        | Current supply overview (total, max, burned, reward)              |
| GET    | `/api/supply/chart?period=`          | Supply over time chart data                                       |
| GET    | `/api/supply/block/:height`          | Supply data for a specific block                                  |
| GET    | `/api/supply/burned`                 | Burned fees summary (total, 24h, 7d, 30d)                          |
| GET    | `/api/tokens`                        | Token and NFT collections (`type` = `all` / `token` / `nft`)       |
| GET    | `/api/tokens/:tokenId`               | Collection detail                                                  |
| GET    | `/api/nfts/:tokenId/:index`          | NFT detail                                                         |
| GET    | `/api/bridge/*`                      | wNAV bridge burns and audit-wallet reconciliation (when configured) |
| GET    | `/api/health`                        | Health check                                                      |

The staking, nodes-history and p2pmsg routes were added in September 2026. Their `period` parameter accepts `24h`, `7d`, `30d`, `1y` (default `30d` for staking, `7d` for nodes and p2pmsg); `/api/outputs/timeline` also accepts `all`. The staking and p2pmsg data come from periodic indexer snapshots of the node (`liststakedcommitmentsdata` every 5 minutes; `getp2pmsginfo`, `getaggregationhint`, `listorders`, `listrfqs` every minute). Against a node without those RPCs, or with p2pmsg disabled, the indexer skips the staking snapshot and records the overlay as not enabled; nothing fails.

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
