# Range proofs

Each BLSCT output's committed amount $v_{\text{amt}}$ must be provably in $[0, 2^{64})$ — otherwise an attacker could commit to a "negative" amount that wraps the field, minting coins out of thin air. Navio uses **Bulletproofs+** (the BP+ variant of Chung–Han–Lee–Ryu 2020) for compact, non-interactive range proofs. The implementation lives at `src/blsct/range_proof/bulletproofs_plus/`; a legacy classic-Bulletproofs tree at `src/blsct/range_proof/bulletproofs/` is retained for compatibility but is not the active prover/verifier for new outputs.

## Why Bulletproofs+

-   **Small proof size.** Logarithmic in bit width: a 64-bit range proof is ~576–672 bytes; aggregated proofs over $m$ outputs grow only by $\log_2 m$ additional $(L_i, R_i)$ pairs.
-   **No trusted setup.** Generators are derived deterministically via hash-to-curve (DST `BLS_SIG_BLS12381G1_XMD:SHA-256_SSWU_RO_POP_`), with the amount generator $G$ bound to a specific `token_id` (`GeneratorDeriver` seed `"proof-of-stake"`, in `src/blsct/range_proof/generators.h`).
-   **Standard security.** Soundness reduces to the discrete-log problem on BLS12-381.

## Commitment form

Navio's Pedersen commitment — across both `bulletproofs_plus/` and the wallet/txfactory code paths — is

$$
C \;=\; v \cdot G \;+\; \gamma \cdot H \;\in\; G_1
$$

where:

-   $G$ is the **amount generator** derived per `token_id` (so commitments to distinct token types are cryptographically separated).
-   $H$ is the **randomness base**, a fixed "nothing-up-my-sleeve" $G_1$ point shared across all tokens.
-   $v \in [0, 2^{64})$ is the amount, $\gamma \in \mathbb{F}_r$ is the blinding scalar.

This is the convention used in `range_proof_logic.cpp` (`V = (g * vsOriginal[i]) + (h * gammas[i])`). Note that when the transaction-level balance equation $(\sum C_{\text{in}} - \sum C_{\text{out}} - \text{fee} \cdot G) = 0$ holds, the $G$ terms cancel and the residual is $r \cdot H$, which is what the balance signature signs under (see [Signatures](signatures.md)).

## Single-output proof

A Bulletproofs+ range proof for $v \in [0, 2^{64})$ with $m = 1$ output consists of the fields produced by `RangeProofLogic<...>::Prove()` and stored in `Proof<T>` (`src/blsct/range_proof/bulletproofs_plus/range_proof.h`):

| Symbol          | Group / field       | Role                                                                                     |
| --------------- | ------------------- | ---------------------------------------------------------------------------------------- |
| $A$             | $G_1$               | Commitment to the bit decomposition vectors $a_L, a_R$, blinded by $\alpha$.             |
| $A_{\text{wip}}$| $G_1$               | Weighted-inner-product commitment from the outer round.                                  |
| $B$             | $G_1$               | Blinding commitment for the inner-product zero-knowledge.                                |
| $L_i, R_i$      | $G_1$               | $2 \cdot \lceil \log_2(m \cdot 64) \rceil$ points from the folding rounds.               |
| $r'$, $s'$      | $\mathbb{F}_r$      | Final scalars of the inner-product argument.                                             |
| $\delta'$       | $\mathbb{F}_r$      | Final blinding scalar.                                                                   |
| $\tau_x$        | $\mathbb{F}_r$      | Embeds the secondary 64-bit message `msg2` (used for amount recovery — see below).        |
| $\alpha_{\text{hat}}$ | $\mathbb{F}_r$| Embeds the primary 64-bit message `msg1` *together with* the first committed amount $v_0$ (the encrypted amount the receiver decrypts during [amount recovery](amount-recovery.md)). |

For a single-output, 64-bit proof this is $3 + 2 \cdot 6 = 15$ $G_1$ elements plus 5 scalars — on the order of **600–650 bytes** depending on witness values. Aggregating $m$ outputs adds $2 \cdot \log_2 m$ extra $G_1$ elements (the $L_i, R_i$ rounds grow).

## Fiat–Shamir transcript

The outer-round challenges $y$ and $z$ are derived from the commitments and generators via SHA-based Fiat–Shamir; subsequent folding-round challenges chain from the transcript (`range_proof_logic.cpp`, `fiat_shamir.h`). Amount recovery re-derives the same $y, z$ to reverse-engineer $v_0$ out of $\alpha_{\text{hat}}$ and $\tau_x$.

## Why Bulletproofs+ over classic Bulletproofs

Bulletproofs+ replaces the classic log-IP argument with a *weighted* inner-product argument, removing two group elements per proof and enabling a cheaper verifier. Navio switched to BP+ as the active prover/verifier; the classic BP source is kept only for legacy verification.


## Verification cost

Verification dominates per-block cost for a well-populated BLSCT block. Typical breakdown:

-   ~1000 scalar-muls in $G_1$ per proof (for a 4-output aggregated 64-bit proof).
-   Multi-exponentiation tricks (Pippenger, Straus) reduce wall-clock by ~3×.
-   Batch verification over all proofs in a block further amortises cost.

A full node on modern hardware verifies a typical mainnet block in tens to hundreds of milliseconds.

## Range proof source

-   `src/blsct/range_proof/` in navio-core — C++ implementation.
-   `src/blsct/range_proof/rpc.cpp` — RPC surface, including [`verifyblsctbalanceproof`](../rpc/blsct.md#verifyblsctbalanceproof) (used for standalone balance proofs, not chain verification).
-   `navio-blsct` WASM/native — TypeScript bindings in `navio-blsct` expose [`RangeProof`](../blsct-lib/privacy.md#rangeproof) for building and verifying proofs off-chain.

## Balance proofs (related but separate)

A **balance proof** is not the same as a range proof:

-   **Range proof** — proves `0 ≤ v < 2^64` for a specific committed amount.
-   **Balance proof** — proves a wallet controls outputs whose total committed amount is at least some threshold $T$, without revealing the exact total or the specific outputs.

The [`createblsctbalanceproof`](../rpc/blsct.md#createblsctbalanceproof) and [`verifyblsctbalanceproof`](../rpc/blsct.md#verifyblsctbalanceproof) RPCs build and verify the latter — useful for solvency proofs, exchange proof-of-reserves, DeFi collateral attestations. Internally this composes Bulletproofs techniques with BLS signatures over the wallet's view-key-controlled outputs.
