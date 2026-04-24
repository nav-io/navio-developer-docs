# Glossary

**Audit key** — 80-byte concatenation of a wallet's view secret and master spending pubkey. Enables a watch-only wallet that can see every incoming balance without being able to spend. See [wallet formats](../concepts/wallet-formats.md#audit-keys).

**Balance proof** — Zero-knowledge proof that a wallet controls outputs totalling ≥ some threshold, without revealing the exact amount or outputs. RPC: [`createblsctbalanceproof`](../rpc/blsct.md#createblsctbalanceproof).

**Balance signature** — Per-transaction BLS signature proving inputs − outputs − fee = 0 without revealing any committed amount. See [signatures](../blsct/signatures.md).

**Bech32m** — Checksum encoding for addresses, a variant of Segwit's bech32 with a different generator polynomial. Navio uses bech32m over 96-byte DPKs. See [double public key](../blsct/double-public-key.md).

**BLS12-381** — A pairing-friendly elliptic curve over a 381-bit prime field. Used for every signature, commitment, and proof in Navio. See [curve](../blsct/curve.md).

**BLSCT** — BLS Confidential Transactions. Navio's base-layer privacy protocol. See [privacy model](../concepts/blsct-model.md).

**Bulletproofs** / **Bulletproofs++** — Compact range proof construction used to prove each hidden amount is in $[0, 2^{64})$. See [range proofs](../blsct/range-proofs.md).

**Coinstake** — Special transaction at `vtx[1]` in a PoS/PoPS block, with a zero-value nonstandard marker as its first output and the block reward in subsequent BLSCT outputs. See [block format](../blsct/block.md).

**Double public key (DPK)** — The 96-byte bundle of a sub-address's view and spend pubkeys. bech32m-encoded to form a user-facing address.

**Ephemeral key $R$** — Fresh per-output public key, sampled by the sender as $r \cdot G$. Stored on-chain; used by the receiver to reconstruct the shared secret. See [output construction](../blsct/outputs.md).

**HashId** — Hash over an output's blinding key and stealth spending key. Used by wallets to look up which sub-address an incoming output is addressed to.

**libblsct** — The C++ library implementing BLSCT primitives. Lives in `src/blsct/` in navio-core. Wrapped by the [navio-blsct](../blsct-lib/index.md) TypeScript library.

**naviod** — The reference Navio full-node daemon.

**navio-blocks** — The block explorer (indexer + API + frontend). See [explorer docs](../explorer/index.md).

**navio-blsct** — TypeScript bindings for libblsct (native + WASM). See [blsct-lib](../blsct-lib/index.md).

**navio-cli** — The CLI wrapper around naviod's JSON-RPC interface.

**navio-core** — The C++ codebase, forked from Bitcoin Core.

**navio-sdk** — High-level TypeScript SDK wrapping navio-blsct plus wallet, sync, and transaction construction. See [sdk](../sdk/index.md).

**navio-staker** — Standalone process that produces coinstake transactions for a wallet with locked stake.

**NFT** — Non-fungible token. On Navio, an 80-hex token id = 64-hex collection + 16-hex subid. Confidential except for the cleartext token id. See [tokens format](../blsct/tokens.md).

**Outpoint** — Reference to a specific output. Navio uses a single 32-byte `output_hash` instead of Bitcoin's `(txid, vout)` pair. See [outpoint model](../concepts/outpoint.md).

**Output hash** — 32-byte canonical identifier of a BLSCT output, computed from the output's contents. Stable across chain re-serialisation.

**Pedersen commitment** — `C = v·H + γ·G` — hides the amount `v` with the blinding factor `γ`. Binding and hiding. See [BLSCT privacy model](../concepts/blsct-model.md#hidden-amounts-pedersen-commitments).

**PoPS** — Proof-of-Private-Stake. Consensus algorithm on every Navio network. Validators prove stake eligibility via a modified RingCT 3.0 set-membership proof + Bulletproofs++ range proof, without revealing the staking UTXO, the amount, or linkage across blocks. See [BLSCT → PoPS](../blsct/pops.md).

**Set element image ($\varphi$)** — $\varphi = h_3^m g_2^f$, a re-randomised copy of the staker's Pedersen commitment under per-block-rebased generators. Navio-specific contribution over RingCT 3.0. DDH-unlinkable across blocks.

**Staked commitment set** — On-chain list of currently-unspent staked output commitment points. Maintained in the UTXO view via `CCoinsViewCache::GetStakedCommitments`. Consensus requires size ≥ 2.

**Kernel hash** — $H(\text{prevTime} \Vert \text{stakeModifier} \Vert \text{time})$. Input to PoPS eligibility.

**Stake modifier (`nStakeModifier`)** — 64-bit rolling value accumulated across PoS history; unpredictable input to kernel hash; prevents cheap grinding.

**$\eta_{\text{FS}}$ / $\eta_\varphi$** — Block-bound entropies. $\eta_{\text{FS}}$ seeds the PoPS proof's Fiat-Shamir transcript (parent hash + parent stake modifier). $\eta_\varphi$ rebases set-membership and range-proof generators from parent height + parent stake modifier + block's transaction list. Together they make `posProof` effectively a signature over the block contents.

**Slashing** — Burning of an equivocating validator's stake via a publicly-verifiable witness that extracts the Pedersen opening $(m, f)$. **Reserved but not activated** on Navio mainnet. See [BLSCT → Slashing](../blsct/slashing.md).

**Finality checkpoint** — Hard-coded `(height, block_hash)` pair in `Consensus::Params::finalityCheckpoints`. Any fork whose block at a listed height disagrees is rejected regardless of chain work. Primary long-range-attack defence.

**Saturating min-value** — `ProofOfStake::SaturateToU64`. Clamps the 256-bit `KH / T_pos` quotient to `UINT64_MAX` on overflow instead of silently truncating. Closes a pathological-difficulty exploit path.

**Time bucketing** — 16-second quantisation (`POPS_TIME_GRANULARITY_SECONDS`) applied to `block.nTime` before feeding it to the kernel hash. Reduces per-slot grinding surface.

**Chain-work binding** — Inclusion of `pindexPrev->nChainWork` in the kernel-hash input. Prevents grinding effort on one fork from carrying over to a parallel private branch rooted at the same ancestor.

**Range proof** — See Bulletproofs. Proof that a committed amount is in $[0, 2^{64})$.

**Shared secret $\sigma$** — `H(r·V)` from the sender's side, or `H(v·R)` from the receiver's side. Both parties compute the same value without interaction. Drives nonce derivation, view tag, stealth spending key.

**Sub-address** — A derived (view, spend) pubkey pair indexed by `(account, index)`. Each wallet maintains pools indexed as 0 (main), -1 (change), -2 (staking).

**Stealth spending key $S'$** — Per-output spending pubkey, derived from the recipient's sub-address spend pubkey plus a hash of the shared secret. Prevents on-chain address reuse.

**Token** — Fungible asset, identified by a 64-hex collection hash. Amounts confidential. See [tokens format](../blsct/tokens.md).

**Token id** — See above. `tokenId` in wire format / RPC is either 64 hex (collection) or 80 hex (collection + nft_id for NFTs).

**Transaction aggregation** — Combining multiple independently-signed BLSCT transactions into one via BLS signature summation. Enables trustless non-interactive swaps, fee sponsorship, CoinJoin-style coordination. See [atomic swaps](../concepts/atomic-swaps.md#intra-chain-aggregated-swaps).

**Transaction keys** — Per-block batch of `(output_hash, ephemeral key, view tag)` tuples, served by nodes / Electrum for efficient wallet sync. See [output detection](../blsct/detection.md).

**View key $v$** — Master secret scalar that enables scanning for incoming outputs. Part of the audit key. Does *not* enable spending.

**View tag $\tau$** — 1-byte hint stored on each output, derived from the shared secret. Lets wallets discard ~255/256 of outputs after a single cheap hash check during sync.

**XOR-stream amount encryption** — Amounts on BLSCT outputs are stored XORed with a keystream derived from the shared-secret-derived nonce. Receiver reverses this on decrypt. See [amount recovery](../blsct/amount-recovery.md).
