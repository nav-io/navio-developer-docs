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
| [Tokens & NFTs](tokens-nfts.md)                       | Curated tutorial view of the token/NFT subset of the BLSCT category.         |
| [Wallet](categories/wallet.md)                        | Bitcoin-derived wallet commands — balance, addresses, fund management.     |
| [Blockchain](categories/blockchain.md)                | Chain queries — blocks, headers, tips, UTXO set stats.                     |
| [Network](categories/network.md)                      | Peers, networking, banning, address manager.                                |
| [Raw transactions](categories/rawtransactions.md)     | Build, sign, send, decode raw transactions.                                |
| [Mining & staking](categories/mining.md)              | Block templates, staking info, submission.                                 |
| [Mempool](categories/mempool.md)                      | Mempool queries, entry lookup, ancestry/descendants.                       |
| [Utility](categories/util.md)                          | Fee estimation, address validation, RPC introspection.                     |

## Error codes

Standard JSON-RPC error numbers apply; Bitcoin Core-derived codes are in [`src/rpc/protocol.h`](https://github.com/nav-io/navio-core/blob/master/src/rpc/protocol.h). BLSCT-specific errors use the generic codes (`RPC_INVALID_ADDRESS_OR_KEY`, `RPC_WALLET_*`). See the [error codes reference](../reference/error-codes.md) for a catalogue.

## Stability

-   Methods in the BLSCT category are **stable** but evolve with protocol releases. Breaking changes are called out in release notes.
-   Response fields are additive — new fields may appear; existing fields are not removed without a deprecation cycle.
-   The exact example hashes / addresses in auto-generated pages come from `HelpExample*` macros in source; they are illustrative, not real on-chain data.
