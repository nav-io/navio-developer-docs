# RPC Reference

Every Navio JSON-RPC command, grouped by category.

!!! info "How this is generated"
    Most pages in this section are *generated* from the [navio-core](https://github.com/nav-io/navio-core) source by the [build pipeline](../explorer/self-host.md) — specifically `scripts/extract-blsct-rpc.py` (BLSCT commands) and the nightly `naviod -help`-driven pipeline (inherited Bitcoin categories). Handwritten text is limited to this index and category intros.

## Calling RPC

### navio-cli

```bash
navio-cli <method> [arg1] [arg2] ...
navio-cli -testnet getblockchaininfo
navio-cli help                     # list all methods (grouped by category)
navio-cli help <method>            # detailed help for a single method
```

### curl / HTTP JSON-RPC

```bash
curl --user $RPC_USER:$RPC_PASS \
    --data-binary '{
        "jsonrpc": "1.0",
        "id": "curltest",
        "method": "getblockchaininfo",
        "params": []
    }' \
    -H 'content-type: text/plain;' \
    http://127.0.0.1:33677/
```

### SDK

The [SDK](../sdk/index.md) wraps the RPC surface for wallet and sync use cases. For ad-hoc RPC, any JSON-RPC client works — the wire format is standard Bitcoin Core JSON-RPC.

## Authentication

Either:

-   `rpcuser` + `rpcpassword` in `navio.conf` (or `rpcauth` for the hashed equivalent).
-   Cookie auth — the daemon writes `$DATADIR/.cookie` on startup; `navio-cli` reads it automatically.

See [Security hardening](../node/security.md#rpc-authentication) for production auth.

## Categories

| Category                                              | Description                                                                 |
| ----------------------------------------------------- | --------------------------------------------------------------------------- |
| [BLSCT](blsct.md)                                     | All Navio-specific BLSCT commands — tokens, NFTs, stake, raw transactions, balance proofs, signed messages, audit key, recovery data. |
| [P2P messaging](p2pmsg.md)                            | Encrypted message bus, user messaging, aggregated sends, RFQ swaps and standing orders. |
| [Tokens & NFTs](tokens-nfts.md)                       | Curated tutorial view of the token/NFT subset of the BLSCT category.         |
| [Wallet](categories/wallet.md)                        | Bitcoin-derived wallet commands — balance, addresses, fund management.     |
| [Blockchain](categories/blockchain.md)                | Chain queries — blocks, headers, tips, UTXO set stats.                     |
| [Network](categories/network.md)                      | Peers, networking, banning, address manager.                                |
| [Raw transactions](categories/rawtransactions.md)     | Build, sign, send, decode raw transactions.                                |
| [Mining & staking](categories/mining.md)              | Block templates, staking info, submission.                                 |
| [Mempool](categories/mempool.md)                      | Mempool queries, entry lookup, ancestry/descendants.                       |
| [Utility](categories/util.md)                          | Fee estimation, address validation, RPC introspection.                     |

## BLSCT-only networks {#blsct-only-networks}

Mainnet, testnet and `blsctregtest` accept only confidential (BLSCT) transactions, and so does signet from v0.3.0, which made it a BLSCT network (see [Networks](../concepts/networks.md#signet)). The RPCs below build, sign or fund transparent transactions, or manage transparent keys, so on these networks they fail with an error naming the BLSCT alternative instead of doing work that can never confirm. Only plain `regtest` is not BLSCT-only and keeps the inherited behaviour. The transparent-RPC refusals themselves are new in v0.3.0.

| RPC | On a BLSCT-only network | Use instead |
| --- | ----------------------- | ----------- |
| `generatetoaddress`, `generatetodescriptor`, `generateblock` | Refused (`RPC_MISC_ERROR`): a transparent coinbase is always rejected | `generatetoblsctaddress`, only up to the network's last proof-of-work height. Above it, blocks must be proof-of-stake |
| `createrawtransaction` | Refused (`RPC_MISC_ERROR`) | [`createblsctrawtransaction`](blsct.md#createblsctrawtransaction) |
| `signrawtransactionwithkey` | Refused (`RPC_MISC_ERROR`) | [`signblsctrawtransaction`](blsct.md#signblsctrawtransaction) |
| `sendmany`, `send`, `sendall` | Refused for every wallet (`RPC_WALLET_ERROR`) | [`sendtoblsctaddress`](blsct.md#sendtoblsctaddress) |
| `fundrawtransaction` | Refused for every wallet | [`fundblsctrawtransaction`](blsct.md#fundblsctrawtransaction) |
| `signrawtransactionwithwallet` | Refused for every wallet | [`signblsctrawtransaction`](blsct.md#signblsctrawtransaction) |
| `bumpfee` | Refused for every wallet | No BLSCT fee bump. Send a new transaction with `sendtoblsctaddress` |
| `settxfee` | Refused: BLSCT fees follow the consensus fee rate | Nothing to set |
| `addmultisigaddress`, `newkeypool` | Refused | BLSCT wallet functionality |
| `keypoolrefill` | Refused on non-BLSCT wallets only | Works on BLSCT wallets (refills the BLSCT sub-address pool) |
| `importprivkey`, `importpubkey`, `importaddress`, `importmulti`, `dumpprivkey` | Refused | `createwallet` with `seed` or `mnemonic`; `dumpmnemonic` / `getblsctseed` |

`sendtoaddress` is unchanged: on these networks it already sends a confidential transaction through `sendtoblsctaddress`.

Some RPCs refuse a **BLSCT wallet** on any network:

-   `dumpwallet` and `importwallet` only handle transparent keys. Back up a BLSCT wallet with `dumpmnemonic` (or `getblsctseed`) plus `backupwallet`, and restore it with `createwallet` `seed`/`mnemonic` or `restorewallet`.
-   `addmultisigaddress` fails with "addmultisigaddress does not support BLSCT (confidential) wallets". `createmultisig` and `addmultisigaddress` refuse the `blsct` and `blsct-stake` address types (`RPC_INVALID_ADDRESS_OR_KEY`).
-   `scantxoutset` and `scanblocks` refuse an `addr()` descriptor of a BLSCT address with `RPC_INVALID_PARAMETER` ("Cannot scan for a BLSCT address: … BLSCT outputs are found by view key (the wallet), not by script"), new in v0.3.0. Every BLSCT output has the same bare `OP_TRUE` script whatever its recipient, so such a scan used to match every BLSCT output. Find a wallet's BLSCT outputs with the wallet (or an [audit-key wallet](../guides/audit-wallet.md)) instead. `raw(51)` is still accepted.

## Removed RPCs

| Removed | Notes |
| ------- | ----- |
| `analyzepsbt`, `combinepsbt`, `converttopsbt`, `createpsbt`, `decodepsbt`, `descriptorprocesspsbt`, `finalizepsbt`, `joinpsbts`, `utxoupdatepsbt` | PSBTs only describe transparent transactions. Build, inspect and sign with `createblsctrawtransaction`, `fundblsctrawtransaction`, `decodeblsctrawtransaction` and `signblsctrawtransaction`. `decodepsbt` and `analyzepsbt` have no replacement. |
| `walletcreatefundedpsbt`, `walletprocesspsbt`, `psbtbumpfee` | No RPC takes or returns a PSBT any more. `send`/`sendall` lost their `psbt` option and result field; `fundrawtransaction` no longer accepts a `psbt` option. |
| `enumeratesigners`, `walletdisplayaddress` | External signer (hardware wallet) support was removed with the `-signer` option. `createwallet` keeps the `external_signer` parameter for positional compatibility, but `true` is an error; `getwalletinfo` no longer returns `external_signer`. |
| `migratewallet` | It converted Berkeley DB legacy wallets to SQLite descriptor wallets. Berkeley DB support is gone and every navio wallet is already stored in SQLite, so in v0.2.2 it could only refuse (`Error: This wallet already uses SQLite`). Legacy wallets still load as before. |
| `listblscttransactions` | Removed in v0.1.5. Use `listtransactions` / `gettransaction`. |

Calling a removed RPC fails with `Method not found` (`-32601`). All removals in this table except `listblscttransactions` are new in **v0.3.0**; v0.2.2 still has them.

## Error codes

Standard JSON-RPC error numbers apply; Bitcoin Core-derived codes are in [`src/rpc/protocol.h`](https://github.com/nav-io/navio-core/blob/master/src/rpc/protocol.h). BLSCT-specific errors use the generic codes (`RPC_INVALID_ADDRESS_OR_KEY`, `RPC_WALLET_*`). See the [error codes reference](../reference/error-codes.md) for a catalogue.

## Stability

-   Methods in the BLSCT category are **stable** but evolve with protocol releases. Breaking changes are called out in release notes.
-   Response fields are usually additive. Fields tied to removed features can be dropped without a deprecation cycle (for example `psbt` from `send`/`sendall` and `external_signer` from `getwalletinfo`); such removals are listed in the [changelog](../reference/changelog.md).
-   The exact example hashes / addresses in auto-generated pages come from `HelpExample*` macros in source; they are illustrative, not real on-chain data.
