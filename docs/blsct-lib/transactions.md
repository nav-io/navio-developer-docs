# Transactions

Transaction-level classes in `@nav-io/navio-blsct` 1.3.0. See [BLSCT → Transaction format](../blsct/transaction.md) for the on-wire layout. Signatures below are checked against the binding source; the [API reference](api/README.md) is authoritative.

There are two families of classes:

-   **Builder inputs** — `TxIn`, `TxOut`, `UnsignedOutput`: what you hand the library to construct a transaction.
-   **Signed transaction views** — `CTx`, `CTxIns` / `CTxIn`, `CTxOuts` / `CTxOut`, `CTxId`, `OutPoint`: what a built or deserialised transaction exposes.

## Build a transaction

```ts
import {
    CTx, TxIn, TxOut, OutPoint, CTxId, TokenId, SubAddr, SubAddrId,
} from '@nav-io/navio-blsct';

const txIn = TxIn.generate(
    inAmount,                         // number, satoshis of the spent output
    gamma,                            // Scalar, the spent output's blinding factor
    spendingKey,                      // Scalar, private key that spends it
    TokenId.default(),
    OutPoint.generate(CTxId.deserialize(outputHashHex)),
    // isStakedCommitment = false, isRbf = false
);

const txOut = TxOut.generate(recipientSubAddr, outAmount, 'memo');

// The fee is computed from the transaction's size, so the inputs rarely cover
// outputs + fee exactly: pass a change address you own (1.3.0+).
const changeAddr = SubAddr.generate(viewKey, spendingPubKey, SubAddrId.generate(-1, 0));
const ctx = CTx.generate([txIn], [txOut], changeAddr);

const rawHex = ctx.serialize();
```

`TxOut.generate(subAddr, amount, memo, tokenId?, outputType?, minStake?, subtractFeeFromAmount?, blindingKey?)` — `outputType` is `TxOutputType.Normal` or `TxOutputType.StakedCommitment`; `blindingKey` lets the caller supply the output's blinding scalar (navio-sdk passes a [seed-derived one](../sdk/sending.md#output-authorship)).

!!! warning "Change address (1.3.0)"
    Without a `changeAddr`, `CTx.generate` fails unless the inputs cover the outputs plus the size-based fee exactly: libblsct refuses to pay change to a key nobody owns.

## `CTx` {#ctx}

```ts
const tx = CTx.deserialize(rawHex);

tx.getCTxId();      // CTxId
tx.getCTxIns();     // CTxIns
tx.getCTxOuts();    // CTxOuts
tx.serialize();     // hex
```

### Aggregation {#ctx-aggregation}

Combine multiple independently-signed BLSCT transactions into one — see [intra-chain swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps) for the protocol context.

```ts
const aggregatedHex: string = CTx.aggregateTransactions([txHexA, txHexB]);
```

Validity condition: the aggregated transaction must be balanced (inputs − outputs − fee = 0) *after* combining. Individual contributors construct unbalanced partial transactions whose commitments cancel out only once the counterparty adds its pieces.

## `CTxIns` / `CTxIn`

```ts
const ins = tx.getCTxIns();
for (let i = 0; i < ins.size(); i++) {
    const input = ins.at(i);
    input.getPrevOutHash();     // CTxId — the spent output hash
    input.getScriptSig();       // Script
    input.getSequence();        // number
    input.getScriptWitness();   // Script
}
```

## `CTxOuts` / `CTxOut`

```ts
const outs = tx.getCTxOuts();
const out = outs.at(0);

out.getValue();             // bigint — 0 for BLSCT outputs
out.getScriptPubKey();      // Script (fixed-size)
out.getScriptPubKeyHex();   // string — the whole scriptPubKey (1.3.0+)
out.getTokenId();           // TokenId
out.getVectorPredicate();   // string — serialized predicate hex
out.getSpendingKey();       // Point
out.getEphemeralKey();      // Point
out.getBlindingKey();       // Point
out.getRangeProof();        // RangeProof
out.getViewTag();           // number
```

!!! note "Changed in 1.3.0"
    `getSpendingKey()` and `getBlindingKey()` return a `Point` (they are public keys); earlier versions returned a `Scalar`. `getScriptPubKeyHex()` returns the script uncut, so a staked commitment's long `OP_STAKED_COMMITMENT … OP_TRUE` script reads in full, which `getScriptPubKey()` does not.

## `CTxId` / `OutPoint`

-   **`CTxId`** — 32-byte hash. `CTxId.deserialize(hex)`, `.serialize()`.
-   **`OutPoint`** — wraps a single output hash, the Navio outpoint form. Contrast with Bitcoin's `(txid, vout)` pair; see [outpoint model](../concepts/outpoint.md). `OutPoint.generate(ctxId)`, `OutPoint.deserialize(hex)`, `.serialize()`.

## Stake delegation (cold staking) {#stake-delegation}

Added in **1.3.0** (and Python 0.0.40). A staked-commitment output can carry an encrypted delegation payload, as a DATA predicate, that lets a third-party staker stake it without being able to spend it.

Attach a delegation while building the output, before signing:

```ts
import { TxOut, TxOutputType, UnsignedOutput, TokenId } from '@nav-io/navio-blsct';

const staked = UnsignedOutput.fromTxOut(
    TxOut.generate(stakeAddr, amount, '', TokenId.default(),
                   TxOutputType.StakedCommitment, minStake),
);
staked.setStakeDelegation(stakeAddr, delegateKey /* Point */, rewardAddress);
```

`setStakeDelegation(destination, delegateKey, rewardAddress)` throws if the output is not a default-token staked commitment, `destination` does not match the output's keys, or `rewardAddress` is empty. The predicate is covered by the output's signature.

Read a delegation back as the owner:

```ts
import {
    parseDataPredicateData, isStakeDelegationDataHex, parseStakeDelegationOwnerInfo,
} from '@nav-io/navio-blsct';

const dataHex = parseDataPredicateData(out.getVectorPredicate()); // payload, without framing
if (isStakeDelegationDataHex(dataHex)) {
    const { delegateKey, rewardAddress } = parseStakeDelegationOwnerInfo(dataHex, nonce);
}
```

-   `parseDataPredicateData(predicateHex)` returns a DATA predicate's payload as hex (throws on any other predicate).
-   `isStakeDelegationDataHex(dataHex)` is a cheap filter to run while syncing.
-   `parseStakeDelegationOwnerInfo(dataHex, nonce)` decrypts the staker key (`Point`) and reward address. `nonce` is the output's BLSCT nonce: for an output paid to one of your sub-addresses, the output's blinding key times your view key.
-   `buildStakeDelegationDataHex(value, gamma, rewardAddress, delegateKey, nonce)` builds a payload directly; prefer `setStakeDelegation`, which takes value, gamma and nonce from the output.

navio-sdk builds on these for [`delegateStake` / `getStakeDelegations`](../sdk/staking.md).

## Example: decode and inspect a raw tx

```ts
import { CTx } from '@nav-io/navio-blsct';

const tx = CTx.deserialize(rawHex);
console.log('txid:', tx.getCTxId().serialize());

const outs = tx.getCTxOuts();
for (let i = 0; i < outs.size(); i++) {
    const out = outs.at(i);
    console.log('out', i, 'view tag', out.getViewTag(), 'script', out.getScriptPubKeyHex());
}
```

For raw-transaction construction end-to-end, see the [raw BLSCT tx guide](../guides/raw-blsct-tx.md).
