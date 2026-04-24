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
| `getindexinfo`             | Status of optional indexes (`txindex`, `blockfilterindex`, `coinstatsindex`) |

## Raw transaction queries

| Command                     | Purpose                                                              |
| --------------------------- | -------------------------------------------------------------------- |
| `getrawtransaction <txid>`  | Raw tx hex (needs `txindex=1` unless tx is in mempool)               |
| `decodeblsctrawtransaction` | [Decode BLSCT raw tx](../blsct.md#decodeblsctrawtransaction)         |

## Mempool

See the [Mempool category](mempool.md).
