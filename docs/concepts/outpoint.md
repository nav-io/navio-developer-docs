# Outpoint model

Navio's biggest structural departure from Bitcoin is the **outpoint identifier**. Tooling written for Bitcoin's `txid:vout` model will silently misbehave if it is not updated. Read this page before you write an indexer, explorer, PSBT-style workflow, or anything that references a specific UTXO.

## Bitcoin: `txid:vout`

A Bitcoin input identifies the output it spends by the pair `(txid, vout)` — the transaction hash and the output index inside that transaction. Equality of outpoints requires equality of *both* fields. If two transactions happen to have the same hash (not possible in practice since BIP-30, but historically allowed), the `vout` disambiguates.

## Navio: single `output_hash`

Every BLSCT output has a **32-byte output hash** that is computed from the output contents (ephemeral key, token id, commitment, script, amount commitments — see [Output construction](../blsct/outputs.md) for the exact preimage). This hash is:

-   **Unique per output.** No two outputs on-chain share an `output_hash`.
-   **The canonical spend reference.** Inputs store only `prev_out: output_hash` (plus a signature). There is no `vout`.
-   **Stable across chain-level re-serialization.** The hash commits to output contents, not to the transaction that created the output.

In the code the output hash is called the **output id** (*outid*): `COutPoint` holds a single `uint256` equal to `CTxOut::GetHash()`, the double-SHA256 of the fully serialized output (BLSCT data and range proof included). `CTransaction` computes the ids of all its outputs once at construction, next to its txid and wtxid. An output hash is **not** a txid: RPC fields named `outputHash` (or similar) cannot be passed where a txid is expected, and vice versa.

The P2P layer is keyed the same way: peers can request the transaction that created an output with `getdata(MSG_OUTPUT_HASH)`, the mempool refuses a transaction that would create an output id already present in the mempool or the UTXO set, and light wallets can stream per-block output keys keyed by output hash. See [P2P protocol → Output-centric identity](p2p-protocol.md#output-centric-identity).

## Why

1.  **Stealth addresses + privacy.** Outputs addressed to the same receiver are unlinkable on-chain, so the information content of a specific output is concentrated in its contents, not in its position inside a transaction.
2.  **Aggregation-friendly.** BLSCT supports transaction aggregation (combining multiple independently-signed transactions into one). Under the aggregated tx, the "parent txid" of a spent output changes — but its `output_hash` does not.
3.  **Simpler UTXO set.** The UTXO set is keyed by a single 32-byte value instead of a 36-byte compound key.
4.  **Self-describing outpoint.** You can hand someone an `output_hash` and they can look up the output directly via [`getblsctoutput`](../rpc/blsct.md#getblsctoutput) without needing the parent txid.

## What this changes

### Indexing

A naive Bitcoin indexer keeps a `UTXO(txid, vout) → output` map. A Navio indexer keeps a `UTXO(output_hash) → output` map. The [navio-blocks explorer](../explorer/index.md) reflects this: the `outputs` table is keyed by `output_hash`, and the `inputs` table references `prev_out` as a single hash — see [Database schema](../explorer/database.md).

`naviod` can keep this map itself: `-outindex=1` (default off, incompatible with pruning) maintains `output hash → (block, txid, vout)` of the creating transaction and, once spent, `(block, txid, vin)` of the spend. It follows reorgs, builds in the background on an existing chain, and reports its state in `getindexinfo` as `outindex`. With it, `getoutputinfo <outputhash>` returns the creating `txid`, `vout`, `blockhash`, `height`, `confirmations` and, if spent in the active chain, a `spentby` object; `gettxfromoutputhash` answers confirmed (including spent) outputs from the index instead of scanning backwards. *(Merged on master; ships in the next release.)*

### RPC shape

RPC methods that accept outpoints take `output_hash` directly:

```bash
navio-cli getblsctoutput <output_hash>
navio-cli unlockblsctoutpoint <output_hash>
```

Contrast with Bitcoin Core's `gettxout <txid> <vout>`.

### PSBT-style flows

Navio does not use the BIP-174 PSBT format. The equivalent flow uses [`createblsctrawtransaction`](../rpc/blsct.md#createblsctrawtransaction) / [`fundblsctrawtransaction`](../rpc/blsct.md#fundblsctrawtransaction) / [`signblsctrawtransaction`](../rpc/blsct.md#signblsctrawtransaction), with inputs given as `output_hash` strings.

### Transaction aggregation

Because inputs reference `output_hash` and signatures are BLS-aggregatable, multiple independently-authored, independently-signed transactions can be combined into a single transaction whose aggregate signature still verifies. The SDK exposes this as [`NavioClient.aggregateTransactions`](../sdk/sending.md#aggregate-transactions) and the underlying library call is [`CTx.aggregateTransactions`](../blsct-lib/transactions.md#ctx-aggregation) in `navio-blsct`.

Use cases:

-   CoinJoin-style coordinated transactions without a trusted coordinator.
-   Fee sponsorship — a third party adds an input paying the fee to someone else's transaction.
-   Atomic cross-party flows (see [atomic swaps](atomic-swaps.md)).
-   Cover traffic: by default (`-aggregatesends=1`) wallet sends merge fee-0 cover candidates pulled over the [p2pmsg overlay](p2p-messaging.md#cover-traffic-aggregation).

### Staker merging

Independently of wallet-side aggregation, the block producer merges **all** user transactions of a block template into one aggregate, so a block with more than one user transaction is `[coinbase, aggregate]`. Merging concatenates inputs and outputs and combines the fee outputs; there is **no cut-through**. If a wallet chained several unconfirmed sends (each spending the previous one's change), the block transaction contains every intermediate change output together with the input that spends it.

A node recognises a mempool transaction as **confirmed by containment** when the block spends all its inputs and creates all its non-fee outputs; it is removed from the mempool as confirmed rather than conflicted. See [P2P protocol → Aggregated blocks](p2p-protocol.md#aggregated-blocks).

### Wallet behaviour for merged sends

A merged send's txid never appears on chain, so the wallet matches its own sends against block transactions by their inputs and outputs. The rules below are those of output-storage BLSCT wallets (`storage_output=true`, the default), as merged on `master` for the next release:

-   **Confirmation.** A send whose inputs and outputs are all contained in a block transaction is confirmed by it, even though its txid differs. Output-storage wallets keep one history row per original send; a wallet restored from seed (which never saw the individual sends) shows the merged chain as one `send` row under the block transaction's txid, with intermediate change left out of both sides of the amount.
-   **Disconnect.** If the block that confirmed a merged send is disconnected, the send returns to unconfirmed and keeps its inputs spent until it confirms again, is conflicted, or is abandoned.
-   **Conflict.** If a block mines a double-spend of one of the aggregate's inputs (for example a cover provider spending its candidate's coin), the wallet marks the aggregate and every send chained on it **conflicted** (`confirmations` goes negative). Their inputs no longer count as spent, so the original coins return to the balance without `abandontransaction`. If the conflicting block is later disconnected, they become unconfirmed again.
-   **Expiry or eviction.** A send that leaves the mempool without a block conflict keeps its inputs spent but is no longer trusted, and its change leaves `getbalances` and `listblsctunspent`. `abandontransaction <txid>` restores the coins it spent. Until then the wallet may rebroadcast it; if the mempool accepts it again, it counts as before.
-   **Trust.** The wallet that broadcast an aggregate records it immediately and trusts its own half's outputs (its change) at 0 confirmations, so sends can chain. Outputs funded only by other parties' inputs (a cover candidate addressed to the wallet, the bought side of a swap) stay untrusted until the aggregate confirms. A wallet restored from the same seed that only sees the aggregate in the mempool treats its change as untrusted.

Chains of unconfirmed aggregated sends are therefore more likely than plain sends to leave the mempool without confirming; prefer waiting for a confirmation before chaining value you cannot afford to have delayed.

### Blockchain reorgs

A reorg invalidates blocks, not individual outputs. Since `output_hash` is content-derived, the *same* output appearing in the canonical chain after a reorg keeps the same hash. SDK sync handles this transparently (see [Synchronization](../sdk/sync.md#reorgs)).

## Implications for explorers

A BLSCT-aware explorer shows:

-   **Output pages** keyed by `output_hash`, not by `txid#vout`.
-   **Spending inputs** linked via the single `prev_out` reference, not a `(txid, vout)` pair.
-   **Amounts** that are `Hidden` for BLSCT outputs; only transparent outputs (OP_RETURN burns) display a number.
-   **No recipient DPK / address.** The on-chain output stores only $R$ (ephemeral key) and $S' = S + \text{HASH}(rV) \cdot G$ (stealth spend pubkey). Recovering the DPK $(V, S)$ requires the recipient's view private key $v$ — without it, inverting $S'$ is mathematically impossible. Explorers cannot render what the math does not permit them to derive.

The navio-blocks explorer's frontend demonstrates this layout on [`/output/:output_hash`](../explorer/index.md).

## Implications for wallets

Wallet software maintains a map `output_hash → (blinding_key, spending_key, view_tag, amount, token_id)`. On a spend the wallet:

1.  Selects a set of `output_hash` values whose recovered amounts sum to at least the target + fee.
2.  Constructs inputs referencing those `output_hash` values.
3.  Produces a balance proof over the commitments of selected inputs and constructed outputs.
4.  Signs each input with the corresponding stealth spending key.
5.  Aggregates signatures into the per-transaction BLS signature.

See the [SDK sending guide](../sdk/sending.md) for the implementation.
