# Atomic swaps walkthrough

Two concrete walkthroughs:

1.  **Cross-chain** BTC ↔ NAV via HTLC.
2.  **Intra-chain** NAV ↔ TokenA via BLS signature aggregation.

Concept doc: [Concepts → Atomic swaps](../concepts/atomic-swaps.md).

---

## Cross-chain HTLC: BTC ↔ NAV

Alice has NAV, wants BTC. Bob has BTC, wants NAV.

### Setup

```
Agreed:
    amount_nav = 1000 NAV
    amount_btc = 0.012 BTC
    Alice timelock = t + 24h
    Bob   timelock = t + 48h    # must be > Alice's

Alice:
    secret_A = random_32_bytes()
    hash_A   = HASH160(secret_A)
    share hash_A with Bob
```

### Step 1 — Bob locks BTC

Bob creates a Bitcoin HTLC:

```
OP_IF
    OP_HASH160 <hash_A> OP_EQUALVERIFY
    <alice_btc_pubkey> OP_CHECKSIG
OP_ELSE
    <bob_timelock> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <bob_btc_pubkey> OP_CHECKSIG
OP_ENDIF
```

Funds 0.012 BTC to this script's P2SH/P2WSH. Broadcasts.

### Step 2 — Alice locks NAV

After seeing Bob's BTC funding confirmed, Alice creates the BLSCT HTLC via:

```bash
navio-cli createblsctrawtransaction \
    '[{...inputs...}]' \
    '[{"address":"<htlc-output>", "amount":1000}]'
```

Where the HTLC script is:

```
OP_IF
    OP_HASH160 <hash_A> OP_EQUALVERIFY
    <bob_nav_bls_pubkey> OP_BLSCHECKSIG
OP_ELSE
    <alice_timelock> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <alice_nav_bls_pubkey> OP_BLSCHECKSIG
OP_ENDIF
```

**Crucial:** set the output's BLSCT spending key to zero so script logic alone governs spending. Use [`deriveblsctspendingkey`](../rpc/blsct.md#deriveblsctspendingkey) helpers.

!!! tip "Refund tracking is automatic in 0.1.3+"
    Alice sells NAV and owns the refund (ELSE / timelock) branch, which is *not* the branch the output is blinded to — historically she had to run [`importblsctscript`](../rpc/blsct.md#importblsctscript) to see and reclaim her own HTLC output. Since navio-core **0.1.3**, `createblsctrawtransaction` auto-registers the `atomic_swap` output as watch-only, so it shows up in [`listblsctunspent`](../rpc/blsct.md#listblsctunspent) with no extra step. Pass `"watch_only": false` on the output to opt out (e.g. when building the swap on another wallet's behalf).

### Step 3 — Alice claims Bob's BTC

Alice builds and broadcasts a Bitcoin tx spending Bob's HTLC on the IF branch:

```
scriptSig: <alice_btc_signature> <secret_A> 1
```

`secret_A` is now public on Bitcoin.

### Step 4 — Bob claims Alice's NAV

Bob extracts `secret_A` from the Bitcoin tx, builds a Navio tx spending Alice's HTLC:

```
scriptSig: <bob_bls_signature> <secret_A> 1
```

Broadcasts on Navio. Swap complete.

### Refund (failure)

If step 3 doesn't happen before Alice's timelock:

-   Alice refunds her NAV via the ELSE branch with her signature.
-   Bob refunds his BTC via the ELSE branch after his (longer) timelock.

Timelock ordering (`alice < bob`) ensures Alice has time to claim before her refund path opens, or to fall back to refund if Bob doesn't publish.

### What can go wrong

-   **Alice claims + Bob doesn't learn secret in time.** Can't happen on-chain — the secret is in a publicly-visible Bitcoin tx.
-   **Chain reorg unwinds Alice's claim.** The secret is still public in whatever Bitcoin tx replaced it; as long as Bob's claim on Navio confirms before Alice's Navio timelock, funds are safe. For high-value swaps, use deeper confirmations.
-   **Fee estimation issues.** The refund path must be funded with enough fee to confirm; RBF or fee-bumping may be required.

---

## Intra-chain aggregated swap: NAV ↔ TokenA

Alice wants to sell 100 TokenA for 10 NAV.

### Step 1 — Alice builds an unbalanced partial tx

Using `createblsctrawtransaction`:

```
inputs:
    - 100 TokenA output from Alice's wallet
outputs:
    - 10 NAV output addressed to Alice's wallet
```

This is unbalanced (Alice spends 100 TokenA, creates 10 NAV — no source for the NAV). Alice signs her input with `signblsctrawtransaction`. The signature covers only what Alice committed to; the transaction is not yet broadcast-able.

Alice publishes the partial raw tx hex to an order book, DM, peer-to-peer channel.

### Step 2 — Bob fills

Bob receives the partial hex. He:

1.  Decodes it with `decodeblsctrawtransaction` to verify the advertised trade.
2.  Builds a completion tx adding:
    -   10 NAV input from his wallet.
    -   100 TokenA output addressed to himself.
3.  Signs his input.

### Step 3 — Aggregate + broadcast

Either party aggregates the two transactions:

```ts
import { NavioClient } from 'navio-sdk';
const client = new NavioClient({ /* … */ });
await client.initialize();

const combined = client.aggregateTransactions([
    aliceOrderHex,
    bobFillHex,
]);

await client.broadcastRawTransaction(combined.rawTx);
console.log('swap tx:', combined.txId);
```

Under the hood, BLS signatures aggregate by summing group elements; the combined signature verifies against the union of signed inputs. Consensus sees a single balanced confidential transaction and accepts it.

### Privacy properties of the aggregated swap

-   Amounts hidden from observers.
-   Token id is cleartext (BLSCT protocol limitation — required for per-asset balance enforcement).
-   No linkage between Alice's "selling" role and Bob's "buying" role visible on-chain.
-   Fee payer is whichever side includes fee-paying NAV inputs (typically encoded in the original partial transaction).

### Multi-party or multi-asset

Same mechanic scales to N parties or N assets — each party contributes inputs and outputs, all signatures aggregate into one. Coordinated CoinJoin-style transactions with no central coordinator are possible.

## References

-   [`CTx.aggregateTransactions`](../blsct-lib/transactions.md#ctx-aggregation) — library primitive.
-   [`NavioClient.aggregateTransactions`](../sdk/sending.md#aggregate-transactions) — SDK wrapper.
-   [BLSCT signatures](../blsct/signatures.md) — why aggregation works.
-   [`OP_BLSCHECKSIG`](../reference/opcodes.md) — opcode `0xbb`.
