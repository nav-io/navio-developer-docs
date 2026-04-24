# Slashing (future work)

Navio ships mainnet **without active slashing**. The opcode (`OP_SLASH_STAKE`) and the `SlashingWitness` serialization format are reserved in consensus so they can be activated later without a disruptive re-wiring, but no valid slashing transaction can be mined today — consensus rejects any input carrying a slashing-unlock script.

This page documents why, what the intended design looks like, and what has to be done before activation.

## Why it is not live

A robust slashing scheme on PoPS needs to satisfy two properties at once:

1.  **Coin unlinkability across blocks**. Two PoPS blocks staked by the same validator (even on the canonical chain) must not be linkable to a common staker, or we lose the privacy we paid BLSCT's complexity for.
2.  **Equivocation extraction**. Two PoPS blocks at the same height, same parent, from the same staker — i.e. double-signing — must let any network observer publicly recover `(m, f)`, the opening of the staker's Pedersen commitment, so the stake can be spent out from under them.

The obvious construction — deterministic per-proof nonces keyed by `(m, f)` — breaks (1). The paper's original proof generates nonces per block via a chain-seeded `eta_phi` rebase, which preserves (1) but breaks (2): fresh randomness in every proof means standard Schnorr-style extraction cannot recover the secret from two transcripts.

The resolution is a **DLEQ-tagged nonce** (verifiable random function keyed by `(m, f)` evaluated at `eta_phi`): two forks produce unlinkable tags by DDH, but an observer can extract `(m, f)` from the two DLEQ relations. That construction is not trivial to plug into the existing Bulletproofs+ / set-membership prover and has not yet been formally specified and audited for Navio.

Until it is, Navio relies on the same defences as classical Proof-of-Stake:

-   **Weak subjectivity**. New nodes sync from a recent finality checkpoint (see [Consensus → Finality](../concepts/consensus.md)).
-   **Reputation + social consensus**. Equivocation is observable on the network; validators caught double-signing can be de-peered and publicly named.
-   **Bounded effective power**. Because stake amounts are confidential, a single equivocating validator cannot efficiently coordinate a large slashable faction — the attack payoff is bounded.

## Reserved primitives already in navio-core

Even though slashing is not activated, the following scaffolding is in the codebase so activation is a surgical change rather than a redesign:

| Primitive                                   | Status                                                   |
| ------------------------------------------- | -------------------------------------------------------- |
| `OP_SLASH_STAKE = 0xbb`                     | Opcode reserved. `script.cpp`, `interpreter.cpp`.         |
| `blsct::SlashingWitness`                    | Struct + `Serialize`/`Unserialize`. `blsct/pos/slash.h`.  |
| `IsSlashingUnlock` / `ParseSlashingUnlock`  | scriptSig pattern detection. `blsct/pos/slash_logic.cpp`. |
| `VerifySlashingInput`                       | Consensus checks (block lookup, eta_phi cross-check, …), keyed behind the `SlashingWitness::Verify` cryptographic core. Present but unreachable until activation. |
| `VerifyTx` rejects `OP_SLASH_STAKE` scripts with `slashing-not-activated` | **Active today.** No slashing-unlock input will confirm. |

This means:

-   Future activation is a block-height gated flip of `VerifySlashingInput` behaviour plus the cryptographic upgrade, not a new opcode or new block field.

## What activation will require

1.  **Cryptographic design**.
    -   DLEQ-tagged nonce construction, fully specified with security proofs.
    -   Formal reduction: extractability of `(m, f)` on equivocation, preservation of zero-knowledge + coin unlinkability on honest use.
2.  **Implementation**.
    -   Update `SetMemProofProver::Prove` to emit the DLEQ tag alongside the existing commit points.
    -   Extend `SlashingWitness::Verify` to use DLEQ-based extraction.
    -   Unit + fuzz tests against the full prover/verifier stack.
3.  **External crypto audit** of the above.
4.  **Activation rule** (hard fork).

## References

-   Consensus code: [`src/blsct/pos/`](https://github.com/nav-io/navio-core/tree/master/src/blsct/pos).
-   Slashing scaffolding: [`src/blsct/pos/slash.h`](https://github.com/nav-io/navio-core/blob/master/src/blsct/pos/slash.h), [`src/blsct/pos/slash_logic.cpp`](https://github.com/nav-io/navio-core/blob/master/src/blsct/pos/slash_logic.cpp).
