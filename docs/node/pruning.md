# Pruning, reindex, txindex

Navio inherits Bitcoin Core's storage model. Three independent knobs:

1.  **Pruning** — discard old block files after validation, cap disk usage.
2.  **txindex** — build a persistent `txid → block location` index (required by most RPC methods that look up an arbitrary transaction).
3.  **Reindex** — rebuild chainstate (`-reindex-chainstate`) or both chainstate and block index (`-reindex`) from scratch.

## Pruning

```ini
# navio.conf
prune=5500        # keep up to 5500 MiB of block files
```

-   `prune=0` disables pruning (default). Blocks and `rev*.dat` files keep growing forever.
-   `prune=1` turns on pruning with the default target (~550 MiB on Bitcoin; check the current navio-core default).
-   `prune=<mib>` targets approximately that many MiB of block files. Chainstate size is not affected.

Incompatible with:

-   `txindex=1` — pruning removes the blocks that the index would reference.
-   `blockfilterindex=1` / `coinstatsindex=1` — same reason.

Serving the chain to other peers with `prune` is allowed (limited to the window of retained blocks). Historical queries (`getblock`, `getrawtransaction` for old txs) return errors once the relevant block is pruned.

## txindex

```ini
txindex=1
```

Enable on any node that needs:

-   `getrawtransaction <txid>` for transactions not in your wallet.
-   Most block-explorer indexers, including [navio-blocks](../explorer/index.md).
-   ElectrumX servers.

Building the index requires rewalking the chain. On a freshly synced node this means:

```bash
naviod -txindex=1 -reindex-chainstate
```

-   `-reindex-chainstate` rebuilds UTXO state without re-downloading blocks — faster.
-   `-reindex` rebuilds both the block index and chainstate. Use if block index is corrupted.

## Reindex

Two flavours:

| Flag                    | What is rebuilt                                       | When to use                                                                 |
| ----------------------- | ----------------------------------------------------- | --------------------------------------------------------------------------- |
| `-reindex-chainstate`   | UTXO set, BLSCT index structures                      | Switching on `txindex`/`blockfilterindex`, fixing chainstate corruption     |
| `-reindex`              | Block index + chainstate                              | Fixing block index corruption, migrating across release boundaries          |

Reindex on a fully synced node can take hours. It re-validates every block and every transaction, so consensus-breaking bugs are surfaced.

### Triggering reindex once (without leaving flag in conf)

```bash
# one-off
naviod -reindex
# …wait for sync to finish…
# Ctrl-C, then:
naviod    # normal startup, no reindex flag
```

The reindex flag is consumed once and then ignored on subsequent starts.

## Reorg handling

Navio's reorg logic is inherited from Bitcoin Core — the node transparently switches to a longer valid chain up to the `MAX_REORG_DEPTH` limit. Wallet sync treats reorgs as:

1.  Detect a divergent block hash at some height `h`.
2.  Roll back UTXOs, wallet outputs, and BLSCT scanning state to `h - 1`.
3.  Re-scan forward on the new chain.

The [SDK sync manager](../sdk/sync.md#reorgs) exposes a reorg callback and handles this automatically for application code.

## Index maintenance — tl;dr

| Scenario                                         | Configure                                                   |
| ------------------------------------------------ | ----------------------------------------------------------- |
| Wallet-only node, minimal disk                   | `prune=2048`                                                |
| Running an explorer                              | `txindex=1`, no prune                                       |
| Running ElectrumX                                | `txindex=1`, optional `-dbcache=4000` for faster sync       |
| Archival / analytics                             | `txindex=1`, `blockfilterindex=1`, `coinstatsindex=1`       |
| Regtest for CI                                   | No pruning, fresh datadir per test, `-dbcache=200`          |
