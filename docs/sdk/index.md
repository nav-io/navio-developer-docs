# SDK — `navio-sdk`

TypeScript SDK for wallet management, blockchain sync, and transaction construction. Works in Node.js and in the browser.

-   **Repository**: [nav-io/navio-sdk](https://github.com/nav-io/navio-sdk)
-   **Package**: `navio-sdk` on npm
-   **License**: MIT
-   **Latest release**: [v0.4.0](https://github.com/nav-io/navio-sdk/releases/tag/v0.4.0) (2026-10-17), built on `@nav-io/navio-blsct` ^1.3.0

```bash
npm install navio-sdk
```

## What it does

-   HD wallet creation and restore (seed, mnemonic, audit key).
-   Password-based wallet encryption (Argon2id + AES-256-GCM).
-   Blockchain synchronisation via either Electrum or direct P2P.
-   Automatic BLSCT output detection with view-tag optimisation.
-   Amount / memo recovery.
-   Confidential transaction construction — NAV, tokens, NFTs, multi-recipient (`sendToMany`).
-   Transaction aggregation for intra-chain swaps / CoinJoin.
-   Peer-to-peer token trading over encrypted messaging (RFQ atomic swaps, standing orders).
-   Staking and cold staking — staked-output tracking, stake delegation, unstaking.
-   Recoverable output blinding keys, so a sender can prove authorship of an output.
-   Cross-platform storage (native IndexedDB in browsers, better-sqlite3 in Node).
-   Reorg detection and automatic recovery.

## Documentation

| Page                                       | Topic                                                                                   |
| ------------------------------------------ | --------------------------------------------------------------------------------------- |
| [Quickstart](quickstart.md)                | Install, create a wallet, sync, check balance                                            |
| [NavioClient](client.md)                   | The main entry point — config, lifecycle, accessors                                     |
| [Wallet management](wallet.md)             | KeyManager, sub-addresses, mnemonic, audit key                                          |
| [Synchronization](sync.md)                 | Electrum vs P2P, background sync, progress callbacks, reorgs                             |
| [Balances & UTXOs](balances.md)            | NAV and asset balances, unspent output queries                                          |
| [Sending transactions](sending.md)         | NAV sends, multi-recipient, token sends, NFT sends, aggregation, output authorship      |
| [Staking](staking.md)                      | Staked balance, cold-staking delegation, unstaking                                      |
| [Token trading](trading.md)                | RFQ atomic swaps — taker/maker peer-to-peer trading                                     |
| [Tokens & NFTs](tokens.md)                 | Collection creation, minting, NFT metadata                                              |
| [Database & storage](database.md)          | Schema, adapters, migration                                                             |
| [Encryption](encryption.md)                | Wallet password protection, encrypted backups                                           |
| [Examples](examples.md)                    | End-to-end snippets                                                                     |
| [API reference](api/README.md)             | Auto-generated TypeDoc reference                                                        |
| [Messaging library](p2pmsg.md)             | `navio-p2pmsg` — standalone client for the p2pmsg bus (separate package)                |

!!! info "API reference auto-generation"
    The [`api/`](api/README.md) tree is regenerated nightly from `navio-sdk`'s source by the docs build pipeline — `typedoc --plugin typedoc-plugin-markdown`. The handwritten pages above give context and examples; the API reference is the source of truth for types and signatures.
