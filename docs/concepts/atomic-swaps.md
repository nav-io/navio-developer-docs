# Atomic swaps

Navio supports two distinct atomic swap patterns:

1.  **Cross-chain HTLC swaps** — swap NAV for BTC, LTC, or any chain that supports hash/time-locked scripts. Secured by shared hash functions and timelock refunds.
2.  **Intra-chain aggregated swaps** — swap NAV ⇄ token ⇄ NFT inside Navio, using *incomplete transactions* and BLS signature aggregation. No hash preimage required; no interactive rounds.

This page covers the mechanics of both. For a concrete end-to-end walkthrough, see [Atomic swaps guide](../guides/atomic-swaps.md).

---

## Cross-chain HTLC swaps

Standard hash-timelock contract (HTLC) pattern adapted for Navio's `OP_BLSCHECKSIG`.

### Requirements on the counter-chain

Any chain supporting the following opcode family works (Bitcoin, Litecoin, and most Bitcoin forks qualify):

-   `OP_HASH160`, `OP_EQUALVERIFY`
-   `OP_IF` / `OP_ELSE` / `OP_ENDIF`
-   `OP_CHECKLOCKTIMEVERIFY`
-   `OP_CHECKSIG` (ECDSA or Schnorr)

### Navio script

Navio substitutes `OP_BLSCHECKSIG` (opcode `0xbb`) for signature verification:

```
OP_IF
    OP_HASH160 <hash_A> OP_EQUALVERIFY
    <Bob's_pubkey> OP_BLSCHECKSIG
OP_ELSE
    <locktime> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <Alice's_pubkey> OP_BLSCHECKSIG
OP_ENDIF
```

The *spending key* of the BLSCT output must be set to zero so that spending is governed exclusively by the script — otherwise the BLSCT stealth spending key would override script logic.

### Protocol

Assume Alice has NAV and wants BTC. Bob has BTC and wants NAV.

| Phase        | Action                                                                                          |
| ------------ | ----------------------------------------------------------------------------------------------- |
| **Setup**    | Alice generates secret $s$, publishes $h = \text{HASH160}(s)$.                                  |
| **Deposit** | Bob locks BTC in an HTLC — unlock with $s$ by Alice before timeout, or refund to Bob after.     |
| **Deposit** | Alice locks NAV in a BLSCT HTLC — unlock with $s$ by Bob before a shorter timeout, or refund.  |
| **Claim**   | Alice spends Bob's BTC HTLC using $s$ (secret becomes public on Bitcoin).                        |
| **Claim**   | Bob reads $s$ from the Bitcoin transaction, spends Alice's NAV HTLC using $s$.                   |
| **Refund**  | If either claim is missed, both outputs refund to their original owners after their respective timelocks. |

Alice's timelock must be **strictly less than** Bob's timelock (typically 24h vs 48h) so Alice has time to claim before her refund path opens.

### Contract construction code

```cpp
// Navio side
CScript CreateNavioSwapContract(
    const uint160& hash,
    const blsct::PublicKey& alice_pubkey,
    const blsct::PublicKey& bob_pubkey,
    uint32_t locktime
) {
    CScript script;
    script << OP_IF;
    script << OP_HASH160 << ToByteVector(hash) << OP_EQUALVERIFY;
    script << ToByteVector(alice_pubkey.GetVch()) << OP_BLSCHECKSIG;
    script << OP_ELSE;
    script << locktime << OP_CHECKLOCKTIMEVERIFY << OP_DROP;
    script << ToByteVector(bob_pubkey.GetVch()) << OP_BLSCHECKSIG;
    script << OP_ENDIF;
    return script;
}

// Bitcoin side
CScript CreateBitcoinSwapContract(
    const uint160& hash,
    const CPubKey& alice_pubkey,
    const CPubKey& bob_pubkey,
    uint32_t locktime
) {
    CScript script;
    script << OP_IF;
    script << OP_HASH160 << ToByteVector(hash) << OP_EQUALVERIFY;
    script << ToByteVector(alice_pubkey) << OP_CHECKSIG;
    script << OP_ELSE;
    script << locktime << OP_CHECKLOCKTIMEVERIFY << OP_DROP;
    script << ToByteVector(bob_pubkey) << OP_CHECKSIG;
    script << OP_ENDIF;
    return script;
}
```

Successful spend path (Alice claiming Bob's BTC):

```
<Alice's_signature> <secret_A> 1
```

Refund path (after timelock):

```
<Owner's_signature> <dummy> 0
```

### Failure modes

-   **Secret never published** → both sides refund after timelock.
-   **Partial publish** — Alice reveals $s$ on BTC but Bob's claim on NAV fails. Bob can still claim because $s$ is on-chain.
-   **Chain reorg** unwinding a claim is possible; use deeper confirmations for high-value swaps.

---

## Intra-chain aggregated swaps

This is a Navio-native mechanism that does **not** exist on chains without BLS signature aggregation and the [single-`output_hash` outpoint](outpoint.md) model. It is used to swap NAV ⇄ token ⇄ NFT inside a single Navio transaction.

### The key insight

Navio transactions are not statically tied to a "payer" — any party can contribute inputs and outputs, and BLS signatures from different parties aggregate into a single signature. A transaction becomes final only when inputs − outputs − fee = 0 (the balance-proof invariant).

This means a single unbalanced, partially-signed transaction can be **completed non-interactively** by a counterparty, and the combined transaction is broadcast as a single atomic unit.

### Incomplete transaction

Alice wants to sell 100 `TokenA` for 10 NAV. She builds a transaction that:

-   Spends 100 `TokenA` from her wallet (input).
-   Creates a 10 NAV output to herself.
-   Signs her inputs with her BLS spending keys.

This transaction is **unbalanced** (100 TokenA enter, 10 NAV leaves — no source for the 10 NAV). A Navio node will reject it if broadcast. But the signatures are valid over the portion of the transaction Alice committed to. She publishes the unbalanced transaction hex as an *order*.

### Non-interactive fill

Bob sees the order. He wants to buy — he adds:

-   A 10 NAV input from his wallet (funding the output Alice made to herself).
-   A 100 `TokenA` output addressed to himself.
-   His BLS signatures on the new input.

He then **aggregates** his signatures with Alice's. Because BLS signatures aggregate by summing group elements and the signed message is the transaction body, the combined signature verifies against the union of (Alice's committed inputs, Bob's added inputs). The combined transaction is now balanced and broadcast.

### Aggregation from the SDK

```ts
const aggregated = client.aggregateTransactions([
    aliceSignedTxHex,
    bobSignedTxHex,
]);
await client.broadcastRawTransaction(aggregated.rawTx);
```

See [`NavioClient.aggregateTransactions`](../sdk/sending.md#aggregate-transactions).

### Multi-asset and NFT swaps

Because the mechanism is *balance-based*, not hash-based, it generalises trivially:

-   Trade 100 `TokenA` + 50 `TokenB` ⇄ 15 NAV.
-   Trade a specific NFT ⇄ N NAV.
-   Trade a basket of NFTs between two users.

All permutations reduce to the same pattern: one side publishes an unbalanced transaction, the other side completes it, signatures aggregate, chain validates.

### Conditional execution

Time locks or other conditions can be added via BLSCT scripts, enabling e.g. **limit-order expiry** (the incomplete transaction becomes invalid after a block height), **auctions**, and **dark-pool-style** matching where multiple fillers race to complete an order.

### Privacy properties

-   **Amounts hidden.** Commitments on every input and output mean only Alice and Bob know the real trade values.
-   **No linkage.** Outside observers see a single balanced BLSCT transaction; they cannot tell that two parties contributed to it.
-   **Order book** privacy depends on the distribution channel. Posting orders on public boards reveals them; peer-to-peer channels keep them private.

### Limitations

-   **No preimage-based atomicity with external chains.** This pattern only works inside Navio. Use HTLC swaps for cross-chain.
-   **Order matching is off-chain** — the protocol defines settlement, not discovery. A relay service, p2p message bus, or dApp is required to circulate orders.
-   **Fee coordination.** Either party must cover the transaction fee; the order must explicitly encode who pays.
