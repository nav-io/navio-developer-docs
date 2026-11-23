# Blockchain RPC

!!! info "Auto-generated"
    Populated by the nightly pipeline from `naviod -help`. Use `navio-cli help <command>` for the current canonical form.

## Block queries

| Command                    | Purpose                                                              |
| -------------------------- | -------------------------------------------------------------------- |
| `getblockcount`            | Return the current chain tip height                                  |
| `getbestblockhash`         | Hash of the tip block                                                 |
| `getblockhash <height>`    | Hash of the block at a specific height                               |
| `getblock <hash> [verbosity]` | Block by hash; verbosity 0 hex, 1 header, 2 full with txs         |
| `getblockheader <hash>`    | Header only                                                          |
| `getblockchaininfo`        | High-level chain state: tip, difficulty, pruned, softfork status     |
| `getchaintips`             | Known tips (active + stale branches)                                 |
| `getdifficulty`            | Current PoPS difficulty (`nBits` → target)                            |
| `getmempoolinfo`           | Size, fee-rate distribution                                          |

## UTXO queries

| Command                    | Purpose                                                              |
| -------------------------- | -------------------------------------------------------------------- |
| `gettxout <txid> <vout>`   | Fetch a transparent UTXO (BLSCT outputs use [`getblsctoutput`](../blsct.md#getblsctoutput)) |
| `gettxoutsetinfo`          | UTXO set statistics (requires `coinstatsindex` for fast path)        |
| `scantxoutset`             | Scan the UTXO set for descriptors. Since v0.2.2 the per-output `amount` is omitted for BLSCT outputs, whose value is hidden. From v0.3.0 an `addr()` of a BLSCT address is refused (see below) |
| `scanblocks`               | Scan blocks for descriptors with block filters. From v0.3.0 an `addr()` of a BLSCT address is refused (see below) |
| `getindexinfo`             | Status of optional indexes (`txindex`, `blockfilterindex`, `coinstatsindex`, and, new in v0.3.0, `outindex`) |
| `gettxfromoutputhash`, `getoutputinfo` | Look up an output by its output hash. See [Output-hash lookups](rawtransactions.md#output-hash-lookups) |

!!! info "`gettxoutsetinfo` hashes changed in v0.3.0"
    From v0.3.0, `gettxoutsetinfo` hashes every coin in one canonical form, so `hash_serialized_3` and `muhash` no longer depend on a node's reorg history. On chains with BLSCT outputs both values differ from earlier releases. An existing `-coinstatsindex` is wiped and rebuilt from genesis in the background on first start after upgrading; until it catches up, index-backed calls report that the index is syncing (pass `use_index=false` to compute from the UTXO set). A pruned node with `-coinstatsindex` must disable the index or `-reindex`. After a downgrade, delete `indexes/coinstats` (or `-reindex`) to rebuild it.

!!! warning "Scans can't find BLSCT outputs by address"
    A BLSCT output's `scriptPubKey` is a bare `OP_TRUE` whatever its recipient, so a script-based scan cannot tell whose it is. From v0.3.0, `scantxoutset` and `scanblocks` refuse `addr(<BLSCT address>)` with `RPC_INVALID_PARAMETER`: "Cannot scan for a BLSCT address: '…'. BLSCT outputs are found by view key (the wallet), not by script". Earlier releases accepted it and matched every BLSCT output (`scantxoutset`) or every block (`scanblocks`), even for an address that was never used. Use a wallet, or a watch-only [audit-key wallet](../../guides/audit-wallet.md), to find the outputs of an address.

## Raw transaction queries

| Command                     | Purpose                                                              |
| --------------------------- | -------------------------------------------------------------------- |
| `getrawtransaction <txid>`  | Raw tx hex (needs `txindex=1` unless tx is in mempool)               |
| `decodeblsctrawtransaction` | [Decode BLSCT raw tx](../blsct.md#decodeblsctrawtransaction)         |

## Mempool

See the [Mempool category](mempool.md).
