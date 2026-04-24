# Two Months to Mainnet: Developer Docs, Hardening Patches, and What They Mean for Navio's Security

*By the Navio team.*

---

We are **two months out from Navio mainnet launch**. The chain is on track, the testnet has been stable at 60-second PoPS blocks for weeks, and the final consensus work is landing on the `testnet-with-consensus-changes` branch. This post covers three things at once:

1.  A new developer documentation portal at **[docs.nav.io](https://docs.nav.io)**.
2.  A round of consensus hardening targeting Proof-of-Private-Stake (PoPS).
3.  An honest account of what we chose to ship, what we deferred, and why.

If you are a validator, a wallet developer, an exchange integrator, or a security researcher: this is the post to read before mainnet.

---

## A single home for Navio technical documentation

Until today, Navio's technical information was spread across a README, a short mkdocs site, and a handful of gists. That is no longer adequate for a chain about to carry real value.

**[docs.nav.io](https://docs.nav.io)** consolidates everything into one site:

-   **Concepts.** The BLSCT privacy model, the single-output-hash outpoint model, consensus, networks, wallet formats.
-   **Node operator.** Build, run, and harden `naviod` on your own infrastructure. No systemd assumed — the project is deliberately agnostic about init systems, and the docs show runit, OpenRC, Docker, tmux, and others.
-   **RPC reference.** Every BLSCT-specific RPC, **auto-generated from navio-core source** on every docs build. No more drift between code and docs.
-   **BLSCT protocol deep-dive.** BLS12-381 primitives, Pedersen commitments, Bulletproofs+ range proofs, stealth addresses, output detection, amount recovery, the full on-wire transaction and block layout, and — new — the Proof-of-Private-Stake construction with its full cryptographic detail.
-   **SDK (`navio-sdk`)** and **libblsct-bindings** (TypeScript + Python today; C, Rust, Go planned).
-   **Block explorer (`navio-blocks`)** — architecture, self-host, REST API reference.
-   **Guides.** End-to-end walkthroughs: a wallet CLI, mint an NFT collection, audit-only deposit monitor, staking VPS, atomic swaps, exchange integration, raw BLSCT transactions.
-   **Reference.** Opcodes (including `OP_BLSCHECKSIG` and the reserved `OP_SLASH_STAKE`), error codes, network constants, glossary, changelog.

The site is built with MkDocs Material, math rendering via MathJax, nightly auto-generation pipeline for SDK / blsct-lib TypeDoc output and for the explorer's OpenAPI spec. Contributions welcome — everything is open-source at [github.com/nav-io/navio-developer-docs](https://github.com/nav-io/navio-developer-docs).

---

## What is PoPS, in one paragraph

Navio runs Proof-of-Private-Stake (PoPS) consensus on every network — mainnet, testnet, signet, regtest. Every block is produced by a validator who attaches a two-part zero-knowledge proof:

1.  A **modified RingCT 3.0 set-membership proof** showing the validator controls *some* Pedersen-committed output in the on-chain staked-commitment set — **without revealing which one**.
2.  A **Bulletproofs+ range proof** showing the hidden stake amount satisfies the block's eligibility threshold derived from the kernel hash.

No validator identity, stake amount, or linkage between blocks produced by the same validator is ever revealed on-chain. The full math lives at [docs.nav.io/blsct/pops](https://docs.nav.io/blsct/pops/).

This is — as far as we know — the first production-ready on-chain consensus protocol that combines privacy for the stake (amount hidden) and privacy for the identity of the staker (set-membership proof), without relying on a trusted setup or a centralised committee.

Which means it is also a protocol that demands careful review before it carries real money.

---

## Pre-mainnet security review

Over the last weeks we ran a systematic audit of the PoPS implementation against the design paper, looking for places where the code could diverge from the intended spec or where the spec itself had sharp corners. Five issues emerged worth addressing before mainnet.

Each has been addressed with a targeted patch on `testnet-with-consensus-changes`.

### 1. Min-value truncation (`SaturateToU64`)

**Issue.** Proof-of-Private-Stake eligibility is `v ≥ min_value`, where `min_value = kernel_hash / next_target`. That quotient is a 256-bit integer. Our implementation narrowed it to 64 bits via `GetUint64(0)`, silently wrapping any overflow. At pathologically tight difficulty, the real threshold could exceed `2^64`, and the wrapped low 64 bits would be an **easier** bound than intended — giving a block producer a free path to mint with tiny stake.

**Fix.** `SaturateToU64` clamps to `UINT64_MAX` on overflow. `ProofOfStakeLogic::Verify` additionally rejects blocks whose saturating `min_value` exceeds the representable `CAmount` range. Latter is belt-and-braces: no legitimate BLSCT commitment opens to that range, so the block's proof was already vacuously invalid — the explicit reject surfaces the condition instead of letting downstream logic trip on it.

### 2. Grinding-surface reduction

**Issue.** The kernel hash consumes the staker-chosen `block.nTime` at 1-second resolution. A grinding attacker with moderate stake can try many candidate timestamps per slot to find one producing a favourable kernel hash.

**Fix (two parts).**

-   **Time bucketing.** `CalculateKernelHash` now quantises `block.nTime` into 16-second buckets. Attacker gets ~3.75× fewer candidate hashes per 60-second slot. Retarget dynamics unchanged in aggregate.
-   **Chain-work binding.** The per-block kernel hash now additionally binds `pindexPrev->nChainWork`. Two forks that diverge from a common ancestor have different `nChainWork` immediately, so grinding effort on one private branch does not carry to a parallel branch. Attacker must burn fresh work for every fork they explore.

### 3. Long-range-attack mitigation (finality checkpoints)

**Issue.** Classical Proof-of-Stake is vulnerable to long-range attacks: an adversary who later acquires old validator keys can retroactively rewrite history from a deep ancestor, because there is no proof-of-work cost to doing so. PoPS inherits this vulnerability.

**Fix.** Hard finality checkpoints added to `Consensus::Params::finalityCheckpoints`. Any candidate chain whose block at a listed height disagrees with the release-baked hash is rejected, regardless of accumulated chain work. Populated per-release from agreed hashes. Strictly additive to the existing `nMinimumChainWork` and `defaultAssumeValid` signals.

This is the standard weak-subjectivity defence used by every major PoS chain. It requires new nodes to trust the release binary they obtained — which they already did for everything else.

### 4. G1 subgroup membership on deserialization

**Issue.** BLS12-381 `G1` has a cofactor, which means there are curve points that are not in the prime-order subgroup `G_r` where the discrete-log assumption holds. A malicious actor could construct a PoPS proof or a signature whose points are on the curve but in a small-order subgroup, bypassing the hardness assumption.

**Fix.** `MclG1Point::SetVch` now calls `mclBnG1_isValidOrder` after deserialization, rejecting non-identity points outside `G_r`. Applied uniformly across every deserialised G1 point — proofs, signatures, public keys, commitments. The identity point is explicitly permitted because it is a valid BLSCT commitment value.

### 5. Slashing — deferred, not broken

**Issue.** A classical PoS chain slashes validators caught double-signing: equivocation proofs burn their stake. PoPS makes this hard because any simple slashing construction has to thread a needle:

-   Coin unlinkability across blocks must be preserved (otherwise we sacrifice the privacy PoPS is built for).
-   Two equivocating blocks from the same validator must let any observer recover the Pedersen opening `(m, f)` of their stake, so the commitment can be publicly opened and spent.

The obvious solution — deterministic nonces keyed by `(m, f)` — breaks coin unlinkability. The obvious alternative — fresh per-block randomness — breaks extraction. The right construction is a **DLEQ-tagged verifiable random function** evaluated at `eta_phi`: tags are pseudo-random per block (unlinkable under DDH) but admit DLEQ-based extraction on equivocation.

**Decision.** We designed, prototyped, reviewed, and — after finding that our initial deterministic-nonce sketch would have broken unlinkability — **deferred** the feature to a post-launch hard fork. The docs page at [docs.nav.io/blsct/slashing](https://docs.nav.io/blsct/slashing/) lays out the design target, the cryptographic properties required, and the activation roadmap.

**What is reserved in code today.** The `OP_SLASH_STAKE` opcode (`0xbb`), the `SlashingWitness` struct + serialization format, the scriptSig pattern detector, and the consensus-verification skeleton are all in the codebase. Consensus **rejects** any input carrying a slashing-unlock scriptSig with `slashing-not-activated`, preventing the opcode from being abused as a free NOP. Activation will be a targeted hard fork: swap in the DLEQ-tagged prover, flip the `VerifySlashingInput` gate. No block-format changes, no opcode renumbering, no client compatibility break.

**Mainnet posture.** Slashing is not our primary defence today. Weak-subjectivity checkpoints, reputation, and peer banning cover the practical equivocation surface. A validator caught double-signing can be de-peered and publicly named, and because stake amounts are confidential, a single equivocating actor cannot efficiently coordinate a large faction — the attack payoff is bounded.

We will ship slashing when we ship slashing that is correct.

---

## Security posture, in plain English

Pre-hardening, PoPS relied on:

-   Bulletproofs+ soundness.
-   Discrete log + decisional Diffie-Hellman on BLS12-381 G1.
-   BLS signature EUF-CMA.
-   Random-oracle hash functions.
-   Honest-majority stake + weak-subjectivity (shared with every PoS chain).

Post-hardening, the residual assumptions are the same — but now backed by:

-   No pathological-difficulty bypass.
-   Measurable grinding resistance.
-   Explicit long-range checkpoints.
-   Subgroup membership checked on every G1 point entering consensus.
-   Slashing gated off until cryptographically correct.

---

## What we ask of validators, integrators, and reviewers

-   **Validators.** Run testnet now with the latest `testnet-with-consensus-changes` branch. Report any equivocation, sync stalls, or proof rejections. Stake locks behave identically to before — 10,000 NAV minimum on every network, PoPS block production via `navio-staker`.
-   **Integrators.** The [SDK](https://docs.nav.io/sdk/) and [libblsct-bindings](https://docs.nav.io/blsct-lib/) are stable for wallet construction, sync, and transaction building. Exchange integrators: read the [audit-wallet guide](https://docs.nav.io/guides/audit-wallet/) and the [exchange-integration guide](https://docs.nav.io/guides/exchange-integration/).
-   **Security researchers.** The full cryptographic construction is documented at [docs.nav.io/blsct/pops](https://docs.nav.io/blsct/pops/). If you find a hole, please report via [security@nav.io](mailto:security@nav.io).

---

## The two-month runway

Between now and mainnet:

-   Initial swap-window tooling and documentation for Navcoin holders migrating to Navio.

Mainnet activation is expected around **Navcoin block height 10,500,000**, approximately end of June 2026 / beginning of July 2026. The swap window from Navcoin closes at height **11,000,000**. Initial genesis supply: **81,743,678 NAV**.

Two months. A lot of cryptography. No shortcuts.

See you at mainnet.

*— The Navio team*

---

*Resources:*
*- Developer docs: [docs.nav.io](https://docs.nav.io)*
*- Source code: [github.com/nav-io/navio-core](https://github.com/nav-io/navio-core)*
*- Discord: [discord.gg/navio](https://discord.com/invite/eBQ2QUkVXy)*
