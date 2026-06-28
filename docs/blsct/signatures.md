# Signatures

Navio uses BLS12-381 signatures for every authentication step in a BLSCT transaction. The aggregatability of BLS is the primary reason Navio chose the curve — per-transaction signatures on many independent messages compress into a single 96-byte group element.

## Ciphersuite

Navio follows the IETF `draft-irtf-cfrg-bls-signature` **`min_pk`** variant (Ethereum 2.0 / `BLS_ETH` mode in mcl):

-   Public keys in $G_1$ (**48 bytes** compressed).
-   Signatures in $G_2$ (**96 bytes** compressed).
-   Hash-to-curve $H : \{0,1\}^* \to G_2$ with DST `BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_`.

`#define BLS_ETH 1` appears at the top of `src/blsct/signature.h` and `src/blsct/arith/mcl/mcl_init.h`. The `Signature` class wraps `mclBnG2`; verification routes through `blsVerify` in the vendored BLS library.

## Basic BLS signing

Signing keypair:

-   Secret scalar $s \in \mathbb{F}_r$.
-   Public key $P = s \cdot g_1 \in G_1$, where $g_1$ is the standard generator of $G_1$.

Signature on message $m$:

$$
\sigma = s \cdot H(m) \in G_2
$$

Verification:

$$
e(g_1,\, \sigma) \;=\; e(P,\, H(m)).
$$

## Aggregation

$n$ signatures $\sigma_i \in G_2$ (on possibly different messages $m_i$ under possibly different pubkeys $P_i \in G_1$) aggregate into

$$
\sigma_{\text{agg}} = \sum_i \sigma_i \;\in\; G_2
$$

verified by a single pairing-product equation

$$
e(g_1,\, \sigma_{\text{agg}}) \;=\; \prod_i e(P_i,\, H(m_i)).
$$

One 96-byte group element on-chain for an arbitrary number of per-input signatures. This is how Navio keeps BLSCT transaction overhead low even when spending many inputs.

## Message augmentation vs basic scheme

Navio mixes two variants of the BLS signature scheme:

-   **Message-augmented** (per-input, per-output, script, token signatures) — the signer prepends its pubkey to the message before hashing: the signed hash is computed over `pk_bytes || msg`. This is the `Verify` path in `public_key.cpp` (`AugmentMessage` → `CoreVerify`). Message augmentation removes rogue-key attacks from aggregation.
-   **Basic** (balance signature only) — the signer signs a **fixed** domain-constant message, `Common::BLSCTBALANCE`. This is the `VerifyBalance` path in `public_key.cpp`. Because the message is a constant and the "pubkey" is the aggregated commitment residual $r \cdot G$ (see below), no augmentation is needed — the construction itself binds the signer to the balance equation.

## Signatures inside a BLSCT transaction

A transaction carries **one** aggregated signature $\sigma_{\text{tx}}$ on the chain, produced by aggregating:

1.  **Per-input signatures** — each spent output's stealth spending key signs a hash committing to the transaction body (inputs, outputs, fee, locktime). Uses the message-augmentation scheme.
2.  **Balance signature** — proves the sender knows the per-input and per-output blinding factors summing to a known multiple of the fee. Formally, the sum of input commitments minus output commitments minus fee equals $r \cdot H$ for some $r$ (where $H$ is the Pedersen randomness base of `generators.h`), and the signer knows $r$. The "balance public key" is this residual $r \cdot H$; the balance signature is a BLS signature under it on the fixed constant `BLSCTBALANCE` (basic scheme — no pubkey augmentation).
3.  **Token / NFT signatures** (conditional) — when minting or creating, the token owner signs with the collection's token-signing key. Message-augmented.
4.  **Script signatures** (conditional) — for non-standard scripts (e.g., HTLC/atomic swaps), additional BLS signatures per script path. Message-augmented.

All verify as one pairing-product equation per block.

## Message commitment

BLSCT signs a hash of the transaction body without the signature fields themselves (Bitcoin's signature-commitment pattern). The hash is built over:

-   Protocol version
-   Input list (each as `prev_out` hash + metadata)
-   Output list (each as `output_hash` contents — ephemeral key, view tag, commitment, range proof, spending key, token id)
-   Locktime
-   Fee commitment

Wallets compute this hash during signing; the chain recomputes it during verification.

## Message signing (standalone)

The RPCs [`signblsmessage`](../rpc/blsct.md#signblsmessage) and [`verifyblsmessage`](../rpc/blsct.md#verifyblsmessage) sign arbitrary byte strings with a BLS key derived from the wallet — useful for proof-of-ownership flows, off-chain order books (see [intra-chain swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps)), and application-level authentication.

## HTLC / atomic swap signatures

Cross-chain HTLC outputs use `OP_BLSCHECKSIG` (opcode `0xbb`). The signature on the unlock branch proves knowledge of the private key corresponding to the pubkey pushed onto the stack. See [atomic swaps](../concepts/atomic-swaps.md#cross-chain-htlc-swaps) for the script pattern and [`deriveblsctspendingkey`](../rpc/blsct.md#deriveblsctspendingkey) for the RPC that computes the key used in the script.

## Batch verification

A node verifying a block batches all aggregate signatures across all transactions into a single pairing-product equation. This yields ~3–5× speedup over sequential per-transaction verification.

## Implementation

-   `src/blsct/signature.cpp` — signing primitives in navio-core.
-   `src/blsct/public_key.cpp`, `public_keys.cpp` — single and multi-key utilities.
-   [`navio-blsct` Signature class](../blsct-lib/primitives.md#signature) — JS/TS wrapper.

## Security notes

-   BLS signatures are **not** rogue-key-attack resistant by themselves when aggregating across adversarial pubkey sets. Per-input, per-output, script, and token signatures use the **message-augmentation** mitigation — each message is prefixed with the signing pubkey, making rogue-key attacks infeasible on those paths.
-   The **balance signature** does *not* use message augmentation (it signs the constant `BLSCTBALANCE`). Its rogue-key resistance comes instead from the construction: the "pubkey" is the unique residual $r \cdot H$ from the commitment balance equation, so a forger would have to break the discrete log of $H$.
-   **Subgroup checks** on incoming signatures are mandatory to reject malleable signatures that land outside the $r$-order subgroup. Beyond the mcl deserialiser under `mclBn_setETHserialization(1)`, Navio adds an explicit guard in `Signature::SetVch` (`src/blsct/signature.cpp`, navio-core #282): every deserialized $G_2$ point is run through `mclBnG2_isValidOrder` and rejected unless it lies in the $r$-order subgroup. This matters because BLS12-381 $G_2$ has a large cofactor, so a point can satisfy the curve equation yet still carry a small-order component — opening the door to signature malleability/forgery. The verification path (`blsAggregateVerifyNoCheck`) skips the order check by design, so the `SetVch` guard is the defence at the deserialization layer.
-   **Proof of possession** is required when adding a new aggregator key to a multi-party flow (relevant for advanced use; not used in plain single-user BLSCT transactions).
