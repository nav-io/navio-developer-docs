# Block Explorer — `navio-blocks`

Full-stack block explorer for Navio. Indexer + REST API + React frontend. Respects BLSCT privacy — amounts and parties are never shown for shielded outputs; only structural data (block, tx counts, types, fees, burn, price, supply, peer map) is exposed.

-   **Repository**: [nav-io/navio-blocks](https://github.com/nav-io/navio-blocks)
-   **Live instance**: (whichever public deployment exists)
-   **License**: MIT

## Documentation

| Page                                                  | Topic                                                                                     |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| [Architecture](architecture.md)                       | Monorepo layout, data flow, tech stack                                                     |
| [Self-host guide](self-host.md)                       | Install, configure, run. Env var reference.                                                |
| [REST API](api/README.md)                             | Auto-generated OpenAPI reference for every endpoint                                         |
| [Database schema](database.md)                        | Tables, indexes, migration strategy                                                        |
| [Supply tracking](supply.md)                          | Per-block subsidy calculation, fee burn, halving                                           |
| [Peer discovery](peer-discovery.md)                   | Direct P2P `version`/`getaddr` crawler, geolocation                                        |
| [Reindexing](reindex.md)                              | Wipe + resync, partial reindex from a height                                               |
| [Customising the frontend](theming.md)                | Cyberpunk palette tokens, adding pages, adding endpoints                                   |

## Pages

| Route             | Page           | Content                                                                    |
| ----------------- | -------------- | -------------------------------------------------------------------------- |
| `/`               | Home           | Search, stat cards, latest blocks + transactions                            |
| `/blocks`         | Block list     | Paginated block table                                                        |
| `/block/:id`      | Block detail   | Header + transaction list                                                    |
| `/tx/:txid`       | Transaction    | Metadata + BLSCT-aware inputs/outputs                                        |
| `/output/:hash`   | Output detail  | Single output view keyed by `output_hash`                                    |
| `/tokens`         | Tokens         | List of known collections                                                    |
| `/token/:id`      | Token detail   | Collection metadata, mint history                                            |
| `/nft/:id`        | NFT detail     | Specific NFT with collection metadata                                        |
| `/network`        | Network        | Node count, world map, version distribution                                   |
| `/supply`         | Supply         | Total, burned, chart, reward schedule                                        |
| `/price`          | Price          | Price chart, volume, market cap                                              |

## Privacy properties

-   **Amounts are hidden** on BLSCT outputs. Explorer displays `Hidden` badge.
-   **Addresses not shown** for BLSCT outputs — only the ephemeral key $R$, view tag, and stealth spend pubkey $S'$ are stored on-chain. Recovering the recipient's DPK $(V, S)$ from these fields is **mathematically impossible without the recipient's view private key $v$** (needed to compute $\text{HASH}(vR)$ and invert $S' = S + \text{HASH}(vR) \cdot G$). Explorers cannot display what they cannot compute.
-   **Transparent outputs** (genesis-time bootstrap outputs seeding the initial PoPS staker set, OP_RETURN burns) show normal values and addresses.
-   **Supply accounting** sums `nBLSCTBlockReward` per PoPS block + minus OP_RETURN burns + genesis/migrated supply per network; fee data is committed in cleartext transaction fields so totals reconcile even without amount disclosure.
