# BLSCT privacy model

**BLSCT** — *BLS Confidential Transactions* — is Navio's base-layer confidential transaction protocol. It combines three cryptographic ideas:

1.  **Pedersen commitments** to hide output amounts while allowing the chain to prove balance (inputs = outputs + fee) without seeing values.
2.  **BLS12-381 pairings** to aggregate balance signatures into a single per-transaction signature and to support set-membership proofs used in PoPS consensus.
3.  **Bulletproofs** (Bulletproofs++ on recent builds) for efficient range proofs that each hidden amount is in $[0, 2^{64})$, so users can't forge negative values that would mint coins.

This page is the conceptual overview. For on-wire byte layouts see [Output construction](../blsct/outputs.md), [Transaction format](../blsct/transaction.md), and the [BLSCT reference](../rpc/blsct.md). For library APIs see [navio-blsct](../blsct-lib/index.md).

## The curve: BLS12-381

BLS12-381 is a pairing-friendly curve used widely in modern cryptography (Ethereum 2.0, Zcash Sapling, Filecoin, Chia). It gives Navio:

-   **Aggregate signatures.** Many BLS signatures on (possibly different) messages combine into a single 96-byte group element that can be verified in one pairing check. This is how Navio compresses per-input signatures and balance proofs.
-   **Pairings** $e: G_1 \times G_2 \to G_T$ used to verify signatures and to build set-membership arguments over Bulletproofs.
-   **Scalars** live in $\mathbb{F}_r$ where $r$ is a 255-bit prime. Scalars are your private keys, blinding factors, and nonces.
-   **Points** live in $G_1$ (48-byte compressed) or $G_2$ (96-byte compressed). Navio's public keys and signatures are $G_1$ points in most places.

The SDK exposes these primitives directly: [`Scalar`](../blsct-lib/primitives.md#scalar) and [`Point`](../blsct-lib/primitives.md#point).

## Stealth addresses via double public keys {#double-public-key}

A classical Bitcoin address is a hash of a single public key. Everyone watching the chain can tell when that address is being reused, and anyone who knows the address can see every payment to it.

BLSCT replaces this with a **double public key (DPK)** — *two* BLS public keys bundled together:

-   `V` = **view key** (derived from the receiver's view secret `v`). Publishes to the sender only; holders of `v` can *scan* outputs addressed to the wallet.
-   `S` = **spending key** (derived from the receiver's spending secret `s`). Holders of `s` can *spend* outputs addressed to the wallet.

For each output the sender picks a fresh random scalar `r` (the *blinding factor*) and produces:

-   **Ephemeral public key** $R = r \cdot G$, stored in the output.
-   **Shared secret** $\sigma = H(r \cdot V)$ — only the receiver (who knows `v`) can recompute $\sigma$ via $\sigma = H(v \cdot R)$.
-   **Stealth spending key** $S' = S + H(\sigma) \cdot G$, derived from $S$ and $\sigma$. This is the actual key that authorises spending of this specific output.

Properties:

-   **Unlinkability.** Two outputs to the same receiver have different stealth spending keys; an observer cannot tell they share a recipient.
-   **Non-interactive.** The receiver publishes the DPK once (as a bech32m address) and the sender computes everything on the fly.
-   **View-only wallets.** Anyone with just `v` (the view key) can see all incoming outputs and their values, but cannot spend them. This is the **audit key** exposed by [`getblsctauditkey`](../rpc/blsct.md) / [`NavioClient.restoreFromAuditKey`](../sdk/client.md#audit-key-restore).

## Hidden amounts: Pedersen commitments

Each output stores a 48-byte **commitment**

$$
C = v \cdot H + \gamma \cdot G
$$

where $v$ is the *amount*, $\gamma$ is a secret blinding factor, and $G, H$ are independent generator points on $G_1$. The commitment is **perfectly hiding** (any $v$ looks the same without $\gamma$) and **computationally binding** (you can't open it to two different values).

Consensus checks transaction balance by summing commitments: if inputs minus outputs minus fees equals the identity point, the transaction is balanced. This works *without* ever revealing a single amount. The proof of knowledge of $\gamma$ values is the per-transaction aggregated balance signature.

## Range proofs

Because commitments hide $v$, a malicious user could in principle commit to a negative amount (really: a huge amount, wrapping past the field order) and print coins. BLSCT prevents this with a **range proof** per hidden output proving

$$
0 \le v < 2^{64}.
$$

Navio uses **Bulletproofs** (Bulletproofs++ on later forks). Per-output proof size is logarithmic in the bit width (~700 bytes). Verification is the single biggest consensus cost in a BLSCT transaction.

See [range proofs](../blsct/range-proofs.md) for the exact format and [`verifyblsctbalanceproof`](../rpc/blsct.md#verifyblsctbalanceproof) for the RPC.

## View tags — faster wallet scanning

Scanning every output with the full stealth-key check would make wallet sync prohibitively slow. BLSCT uses a **view tag** — a 16-bit hint derived from the shared secret.

For each output the sender stores `view_tag = Hash(r·V) & 0xFFFF` (uint16; source: `src/blsct/wallet/helpers.cpp:15`). During sync the receiver computes `Hash(v·R) & 0xFFFF` using the private view key $v$; if it doesn't match the stored tag they skip the full stealth-derivation path. Collision rate is $1/65536$, so only a tiny fraction of outputs require the expensive stealth-key reconstruction. This optimisation drops sync time from hours to minutes on modest hardware.

Note the scalar-multiplication $v \cdot R$ still happens per output — the saving is on downstream steps (spending-key derivation, sub-address lookup, amount decryption).

The [SDK](../sdk/sync.md) does this automatically; the explicit primitive is [`KeyManager.calculateViewTag`](../sdk/wallet.md#key-manager).

## Signatures

BLSCT transactions carry multiple kinds of BLS signatures, all aggregatable:

-   **Balance signature.** Proves the sender knows the blinding factors that make inputs − outputs − fee = 0.
-   **Input signatures.** One per spent UTXO, on a message that commits to the spent stealth spending key and the transaction body.
-   **Token creation / mint signatures.** For `createtoken`, `createnft`, `minttoken`, `mintnft`.
-   **Message signatures.** Standalone message signing via [`signblsmessage`](../rpc/blsct.md#signblsmessage) and [`verifyblsmessage`](../rpc/blsct.md#verifyblsmessage).

All of the above compress into a single transaction-level signature through BLS aggregation. See [signatures](../blsct/signatures.md).

## Tokens and NFTs under BLSCT

Tokens and NFTs are native BLSCT outputs — they carry the same commitment / range-proof / stealth-address machinery, plus a `token_id`. Token amounts are also hidden. NFTs are a token with a unique `subid` making the balance effectively "1 of this id". See [Tokens & NFTs](../rpc/tokens-nfts.md) and the [token format](../blsct/tokens.md).

## What an observer sees vs. does not see

| Observer sees                                                    | Observer does **not** see                                               |
| ---------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Block height, block hash, block time, coinstake marker, `posProof` | Validator identity, stake amount, or linkage of blocks by same staker |
| Transaction hash, input count, output count, fee                 | Sender address, receiver address, amount, token id on BLSCT outputs     |
| Output hashes, ephemeral public keys, view tags                  | Whether two outputs are to the same receiver                            |
| Range proofs and balance signature                               | The committed amounts or blinding factors                               |
| Script type (BLSCT vs. legacy transparent fallback, if any)      | Memo field (encrypted with the shared secret, only receiver can read)   |

## Where to go next

-   On-wire byte layout: [output construction](../blsct/outputs.md), [transaction format](../blsct/transaction.md), [block format](../blsct/block.md).
-   Invoking BLSCT operations: [RPC reference](../rpc/blsct.md) or the [SDK guide](../sdk/index.md).
-   Curve primitives in code: [`navio-blsct` library](../blsct-lib/index.md).
