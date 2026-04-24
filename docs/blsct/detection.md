# Output detection

How a wallet finds outputs that belong to it among the millions on the chain, without trial-decrypting every field of every output.

## The problem

Every BLSCT output on-chain is an **ECDH-style stealth** output — unlinkable to any public identity. A wallet cannot simply look up "addresses I own" in an index. Instead it must test each output against its private view key.

This asymmetry is fundamental: the on-chain output exposes $R = r \cdot g_1$, $B = r \cdot S_{a,i}$, and $S' = S_{a,i} + \text{H}_s(\eta, 0) \cdot g_1$, where $\eta = v_{a,i} \cdot R = r \cdot V_{a,i}$. **Without the view private key $v_{a,i}$ (or the sender's ephemeral scalar $r$), recovering the recipient's DPK $(V_{a,i}, S_{a,i})$ from $(R, B, S')$ is computationally infeasible** (DDH/DLP). Detection is therefore a wallet-local operation by necessity, not policy — and the same reason explorers cannot show recipient addresses on output pages.

A naive approach — compute the full elliptic-curve operation per output — is too slow. A chain with 10M outputs would require 10M scalar multiplications to sync from scratch. Navio uses a two-stage filter: cheap view tag match first, full ECDH only on match.

## Two-stage detection

### Stage 1: view-tag filter

For each output, the chain stores a 2-byte (16-bit) **view tag** $\tau$ (see [output construction](outputs.md)). The source formula (`CalculateViewTag` in `src/blsct/wallet/helpers.cpp:12`) is

$$
\tau \;=\; \text{SHA256}\bigl(\eta\bigr).\text{GetUint64}(0) \;\&\; \text{0xFFFF}, \qquad \eta \;=\; v \cdot R \;=\; r \cdot V_{a,i} \in G_1.
$$

For **batch scanning** over many outputs in a row, `CalculateViewTagBatch` parallelises the per-output scalar multiplications across threads. `TransactionKeysSync` in the SDK fetches per-block `(output_hash, output.blindingKey, output.viewTag)` tuples via:

-   RPC: [`getblsctrecoverydata`](../rpc/blsct.md#getblsctrecoverydata)
-   Electrum: [`blockchain.block.get_txs_keys`](../node/electrumx.md#blockchainblockget_txs_keys) / `blockchain.block.get_range_txs_keys`

Per output the wallet runs:

1.  Compute $\eta = v \cdot B$ where $B = \text{output.blsctData.blindingKey}$ — the stored DH pre-point $r \cdot S_{a,i}$. Note $v \cdot B = v \cdot r \cdot S_{a,i} = r \cdot V_{a,i} = \eta$, so this is a **single** $G_1$ scalar-multiplication (not one per sub-address).
2.  Compute $\tau_{\text{candidate}} = \text{SHA256}(\eta).\text{GetUint64}(0) \;\&\; \text{0xFFFF}$.
3.  Compare against the stored `viewTag`.
4.  If they match, proceed to the full stealth-key check; otherwise discard.

Storing $B = r \cdot S_{a,i}$ (instead of only $R$) is the optimisation that makes this one scalar-mul: without $B$, the wallet would have to test each tracked sub-address by computing $v \cdot R$ and comparing against $r \cdot V_{a,i}$, which still needs the sub-address-derived view pubkey. Collision rate for the 16-bit tag is $1/2^{16} \approx 1/65536$, so only a tiny fraction of outputs hit the expensive stage-2 path.

### Stage 2: full stealth-key check

For each output that passes the view-tag filter, the code path is `KeyMan::IsMine` → `CalculateHashId` (`src/blsct/wallet/helpers.cpp:60`):

1.  Reuse $\eta$ from stage 1.
2.  Compute $\text{tweak} = \text{H}_s(\eta, \text{salt}{=}0)$ via `MclG1Point::GetHashWithSalt(0)`.
3.  Invert the stealth formula: $S_{a,i}^{\text{derived}} = S' - \text{tweak} \cdot g_1$, where $S' = \text{output.blsctData.spendingKey}$.
4.  Wrap $S_{a,i}^{\text{derived}}$ as a `blsct::PublicKey` and take its `CKeyID` (`Hash160`). This is the **canonical `hashId`**.
5.  Look `hashId` up in the wallet's sub-address map (`HaveSubAddress(hashId)`). If present, the output belongs to the sub-address registered under that id.

The wallet precomputes the `hashId` once per output; matching is then a $O(1)$ hash-map lookup regardless of sub-address pool size, not an iteration over each tracked $(V_{a,i}, S_{a,i})$.

## Transaction key synchronisation

The bulk of sync work is fetching per-block `(output_hash, R, view_tag)` tuples and performing the view-tag filter on them. The SDK's sync manager does this in [`TransactionKeysSync`](../sdk/sync.md) with parallel batching:

-   **Electrum backend** — uses `blockchain.block.get_range_txs_keys` to fetch many blocks in one call, respecting `max_send` limits.
-   **P2P backend** — uses a custom protocol extension defined in [`src/p2p/*`](https://github.com/nav-io/navio-core/blob/master/src/p2p) that streams transaction keys directly from a connected full node.

See [SDK synchronisation](../sdk/sync.md) for the full sync state machine, reorg handling, and progress callbacks.

## Expected detection cost

| Wallet size                | Outputs scanned per full sync | ECDH operations required |
| -------------------------- | ----------------------------- | ------------------------ |
| Just-created wallet, no history | 0 | 0 |
| Typical user, 10 incoming txs over a year | ~few million | ~few million scalar-muls for stage 1, ≤ millions × 1/65 536 for stage 2 |
| Exchange audit wallet, 100k incoming txs | full chain scan | full chain ECDH (stage 1) |

For a full chain scan with stage 1, sync takes minutes to low hours on modern hardware — orders of magnitude faster than a naive full stealth-address scan.

## SDK integration

```ts
await client.sync({
    onProgress: (h, tip, blocks, txKeys, isReorg) => {
        console.log(`at ${h}/${tip}; ${blocks} blocks, ${txKeys} tx-keys, reorg=${isReorg}`);
    },
});
```

Background sync keeps the wallet up-to-date with the chain tip:

```ts
await client.startBackgroundSync({
    pollInterval: 10000,
    onNewTransaction: (txHash, outputHash, amount) => {
        console.log(`received ${amount} sats via ${outputHash}`);
    },
});
```

See the [SDK sync page](../sdk/sync.md).
