# BLS12-381 curve

BLS12-381 is a pairing-friendly elliptic curve defined over a 381-bit prime field. Navio uses it for every BLSCT primitive — keys, commitments, signatures, and range proofs. This page covers the concrete numbers, serialisation formats, and how Navio uses each group.

## Field parameters

-   **Base field prime**: $p \approx 2^{381}$.
-   **Scalar field prime (group order)**: $r = $ 255-bit prime. Scalars are elements of $\mathbb{F}_r$.
-   **Embedding degree**: 12. The target group $G_T$ has order $r$ in $\mathbb{F}_{p^{12}}$.

## Groups

| Group | Defined over | Compressed size | Navio uses it for                                                              |
| ----- | ------------ | --------------- | ------------------------------------------------------------------------------ |
| $G_1$ | $E(\mathbb{F}_p)$      | 48 bytes        | Public keys (view, spend, output), Pedersen commitment points, all generators  |
| $G_2$ | $E'(\mathbb{F}_{p^2})$ | 96 bytes        | **Signatures** (BLS `min_pk` variant — pubkeys in $G_1$, signatures in $G_2$)  |
| $G_T$ | $\mathbb{F}_{p^{12}}$  | 576 bytes uncompressed | Pairing output, used in verification only (never stored on-chain)       |

Navio follows the Ethereum 2.0 / IETF `min_pk` ciphersuite: pubkeys live in $G_1$ (48 bytes on the wire), signatures in $G_2$ (96 bytes on the wire). Set at compile time via `#define BLS_ETH 1` in `src/blsct/signature.h` and `src/blsct/arith/mcl/mcl_init.h`, and activated at init via `mclBn_setETHserialization(1)`.

!!! note "Arithmetic backend"
    The BLS12-381 arithmetic backend is migrating from herumi/mcl to a vendored **supranational/blst** (the same library eth2 clients use), which reindexes a mainnet chain roughly 2× faster on x86_64, with the verification-heavy operations (MSM, set-membership verify, point deserialization) seeing the largest wins. The `min_pk` serialisation and every on-wire format are unchanged. Subgroup membership on $G_1$ is enforced with a **deterministic per-point** check (`blst_p1_in_g1`) rather than a random-linear-combination, so two nodes always agree on whether a proof-supplied point is valid.

## Pairing

The pairing is $e : G_1 \times G_2 \to G_T$ with the bilinearity property

$$
e(a P, b Q) = e(P, Q)^{a b}
$$

for all $P \in G_1, Q \in G_2, a, b \in \mathbb{F}_r$.

This enables BLS signature verification. With pubkey $pk \in G_1$, signature $\sigma \in G_2$, and hash-to-curve $H : \{0,1\}^* \to G_2$, `verify(pk, m, σ)` succeeds iff

$$
e(g_1,\, \sigma) = e(pk,\, H(m))
$$

where $g_1$ is the generator of $G_1$.

## Aggregate signatures

$n$ signatures $\sigma_i$ on (possibly distinct) messages $m_i$ under public keys $pk_i$ aggregate into a single $G_2$ element

$$
\sigma_{\text{agg}} = \sum_i \sigma_i \in G_2
$$

verified by a single product of pairings:

$$
e(g_1,\, \sigma_{\text{agg}}) = \prod_i e(pk_i,\, H(m_i)).
$$

This is the primitive Navio uses to compress all per-transaction signatures (inputs, balance proof, token proofs) into a single **96-byte** $G_2$ element on-chain.

## Serialisation

Navio follows the [IETF draft for BLS signatures](https://datatracker.ietf.org/doc/draft-irtf-cfrg-bls-signature/) and the [ZCash BLS12-381 compression format](https://github.com/zcash/librustzcash/blob/main/pairing/src/bls12_381/README.md#serialization). In short:

Navio uses the Ethereum 2.0 serialisation (`mclBn_setETHserialization(1)` in `src/blsct/arith/mcl/mcl_init.h`):

-   **$G_1$ compressed** (48 bytes) — three flag bits live in the top three bits of the first byte:
    -   `0x80` (bit 7) — *compression* flag (always 1 for compressed form; 0 for the 96-byte uncompressed encoding).
    -   `0x40` (bit 6) — *infinity* flag (point at infinity when set; remaining bits must be zero).
    -   `0x20` (bit 5) — *y-sign* flag (selects the larger of the two square roots of $y^2 = x^3 + 4$).
    -   The remaining 381 bits encode the $x$-coordinate as an element of $\mathbb{F}_p$.
-   **$G_2$ compressed** (96 bytes) — same three flag bits on the first byte; body encodes the two $\mathbb{F}_p$ components of $x \in \mathbb{F}_{p^2}$.
-   **$\mathbb{F}_r$ scalars** (32 bytes) — **little-endian**. Scalars are reduced mod $r$.
-   **Subgroup checks** — every deserialised $G_1$ / $G_2$ point is validated to lie in the prime-order-$r$ subgroup (via `mclBnG1_isValidOrder` / `mclBnG2_isValidOrder`), rejecting small-subgroup attacks on the cofactor.

The [navio-blsct library](../blsct-lib/primitives.md) exposes `Scalar` (32 bytes) and `Point` (48 bytes for $G_1$).

## Hash-to-curve

Navio uses the IETF `hash_to_curve` draft with the SSWU map. Two domain-separation tags are in active use:

-   **$G_2$ (signatures)** — $H : \{0,1\}^* \to G_2$ with DST `BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_`. This is the hash used inside BLS signature sign/verify (message → $G_2$ point).
-   **$G_1$ (generators)** — $H : \{0,1\}^* \to G_1$ with DST `BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_POP_`. This is used to derive:
    -   The Pedersen amount generator $G$ per `token_id` (`GeneratorDeriver` with the seed string `"proof-of-stake"` in `src/blsct/range_proof/generators.h`).
    -   The fixed Pedersen randomness base $H$ (cached at `m_H` and shared across token IDs).
    -   The vectors $G_i, H_i$ for range-proof inner products.

## Why BLS12-381

-   **Strong security** (~128-bit), widely audited.
-   **Efficient pairings and aggregation** — critical for per-block verification cost.
-   **Used across ecosystem** — Ethereum 2.0, Zcash Sapling, Filecoin, Chia. Navio benefits from the existing optimised C/C++ implementations in `libblsct` and downstream Rust/Go/JS bindings.
-   **Compressibility** — 48-byte $G_1$ points for keys/commitments and 96-byte $G_2$ signatures keep on-chain footprint small.
