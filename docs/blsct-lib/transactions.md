# Transactions

Transaction-level classes. See [BLSCT → Transaction format](../blsct/transaction.md) for the on-wire layout.

## `CTx` {#ctx}

Top-level BLSCT transaction.

```ts
import { CTx } from 'navio-blsct';

// Deserialise from raw hex
const tx = CTx.fromHex(rawHex);

tx.getTxId();                   // CTxId
tx.getInputs();                 // CTxIns
tx.getOutputs();                // CTxOuts
tx.getVersion();                // number
tx.getLockTime();               // number

tx.toHex();
tx.toBytes();
tx.toJSON();                    // human-readable JSON
```

### Aggregation {#ctx-aggregation}

Combine multiple independently-signed BLSCT transactions into one — see [intra-chain swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps) for the protocol context.

```ts
const aggregated = CTx.aggregateTransactions([txA, txB]);
await node.broadcast(aggregated.toHex());
```

Validity condition: the aggregated transaction must be balanced (inputs − outputs − fee = 0) *after* combining. Individual contributors construct unbalanced partial transactions whose commitments cancel out only once the counterparty adds its pieces.

## `CTxIn` / `CTxIns`

Individual input and the collection wrapper.

```ts
import { CTxIn, CTxIns } from 'navio-blsct';

const input = new CTxIn({
    prevOut: outputHashHex,       // 64-hex
    scriptSig: script,            // Script
    sequence: 0xffffffff,
});

const ins = new CTxIns();
ins.push(input);
ins.size();
```

## `CTxOut` / `CTxOuts`

Output and collection. Holds everything from [output construction](../blsct/outputs.md).

```ts
import { CTxOut, CTxOuts, CTxOutBLSCTData } from 'navio-blsct';

const bdata = new CTxOutBLSCTData({
    blindingKey: pointR,
    viewTag:     0x7f,
    spendingKey: pointSPrime,
    rangeProof:  rp,
    // ... amount / gamma ciphertext
});

const out = new CTxOut({
    value:         0n,            // 0 for BLSCT
    scriptPubKey:  script,
    tokenId:       null,          // or Uint8Array(32 | 40)
    blsctData:     bdata,
});

out.getOutputHash();              // 64-hex canonical id
```

## `CTxId` / `OutPoint`

Identifiers.

-   **`CTxId`** — 32-byte transaction hash. Immutable once the tx is built.
-   **`OutPoint`** — a wrapper around a single `output_hash`, the Navio outpoint form. Contrast with Bitcoin's `(txid, vout)` pair; see [outpoint model](../concepts/outpoint.md).

```ts
import { CTxId, OutPoint } from 'navio-blsct';

const id = CTxId.fromHex(hex);
const op = OutPoint.fromHex(outputHashHex);
op.toHex();
```

## Example: decode and inspect a raw tx

```ts
import { CTx } from 'navio-blsct';

const rawHex = '0100000001...';
const tx = CTx.fromHex(rawHex);
console.log('txid:', tx.getTxId().toHex());
console.log('ins:',  tx.getInputs().size());
console.log('outs:', tx.getOutputs().size());

for (const out of tx.getOutputs()) {
    console.log('  out', out.getOutputHash(), 'token', out.getTokenId());
}
```

For raw-transaction construction end-to-end, see the [raw BLSCT tx guide](../guides/raw-blsct-tx.md).
