# Staking

Navio's staking produces **Proof-of-Private-Stake (PoPS)** blocks on the current BLSCT chains: **mainnet**, **testnet**, and **blsctregtest**. Operators lock a portion of wallet funds as a Pedersen-committed stake; eligible hidden-amount commitments participate in the stake lottery and mint blocks when their ZK eligibility proof verifies.

Full protocol details (math, crypto proofs, verifier equations): [BLSCT → Proof-of-Private-Stake](../blsct/pops.md).

## How to stake

The **only** way to stake is via the standalone `navio-staker` binary. There is no in-daemon staking option — `naviod` itself does not produce blocks; it validates them. `navio-staker` connects to a running `naviod` over JSON-RPC, polls for eligible staked commitments, constructs the PoPS proof (set-membership + range proof), and submits candidate blocks.

## Hardware requirements

BLSCT verification is heavier than transparent signatures: every block carries Bulletproofs++ range proofs and a BLS aggregate signature verify, and the staker additionally builds a set-membership proof + range proof against the current staked commitment set. RAM scales with the staked-set cap (`N = 1024` commitments, padded to the next power of two) and with `dbcache` (default 2048 MiB).

### Minimum (survives, but slow IBD and tight headroom)

| Resource | Value                                                    |
| -------- | -------------------------------------------------------- |
| CPU      | 2 vCPU, x86-64 with AES-NI + AVX2, or ARMv8 with crypto  |
| RAM      | 4 GB                                                     |
| Disk     | 40 GB SSD (NVMe strongly preferred), `prune=4096`        |
| Network  | 50 Mbps symmetric, stable; monthly cap ≥ 100 GB          |
| Clock    | NTP-synced (`chrony` or equivalent); drift > 30 s risks stale PoPS templates |

### Recommended (mainnet, long-running operator)

| Resource | Value                                                                |
| -------- | -------------------------------------------------------------------- |
| CPU      | 8 vCPU / 8 physical cores, modern x86-64 (AVX2) or ARMv8.2+ with crypto extensions. Navio parallelises heavily — Bulletproofs++ range-proof verification fans out one `std::async` task per proof, view-tag detection batches across threads, and the block check queue validates scripts in parallel. More cores ≈ faster IBD and lower per-block validation latency. Microbench on `bench_navio`: `BLSCTRPVerify` per-proof cost drops ~2.7× going from 1 → 8 parallel proofs. |
| RAM      | 8 GB (leaves headroom for `dbcache=2048` + mempool + OS page cache)  |
| Disk     | 200 GB NVMe SSD, unpruned; 4 KiB random-read IOPS ≥ 10k              |
| Network  | 100 Mbps symmetric, low-jitter; monthly cap ≥ 1 TB                   |
| Clock    | NTP, max ± 2 s skew from wall time                                   |

### Notes

- **Sustained load is low.** After IBD, a synced node running `navio-staker` typically sits at < 10 % CPU between slots, spiking for a few hundred ms when validating a new block or assembling a candidate template. Provision for peak, not mean.
- **Disk growth.** Unpruned mainnet grows with chain size; `prune=N` caps block-file usage at roughly `N` MiB but chainstate still grows with UTXO count.
- **More CPU cores help validation, not win rate.** PoPS is stake-weighted: extra compute does not increase the probability of minting a block. But more cores *do* shorten IBD (parallel range-proof + view-tag batches), reduce per-block validation latency, and give you headroom when a busy block with many BLSCT outputs arrives. A fast-to-validate node also finishes its own candidate templates quicker, reducing the stale-template risk on busy networks. GPUs / ASICs do not apply — the parallel work is on general-purpose BLS12-381 pairings, not a hash function.
- **Home connection is fine** as long as uptime is solid. A VPS is mostly about availability, not throughput.
- Tighter testnet-only sizing and a step-by-step VPS bringup: [Run a staking node on a VPS](../guides/staking-vps.md#vps-sizing).

## Requirements

-   `naviod` fully synced to chain tip, with RPC enabled.
-   A wallet holding **≥ 10,000 NAV** locked as stake on mainnet / testnet (`100 NAV` on `blsctregtest`).
-   Wallet unlocked for staking (`walletpassphrase <pw> <timeout> true` — third argument is staking-only unlock).

No stake-age minimum. Newly locked outputs become eligible as soon as they are confirmed and present in the staked commitment set.

## Lock stake

```bash
navio-cli -testnet stakelock 10000
```

Creates a transaction locking 10,000 NAV into staking sub-addresses (account `-2`). The output is marked as a staked commitment rather than spendable for normal sends.

## Run the staker

```bash
navio-staker -testnet -wallet=wallet
```

Keep it running. It will:

1.  Call `getblocktemplate` to learn the current sampled `staked_commitments` ring, `eta_fiat_shamir`, `eta_phi`, `prev_time`, `modifier`, `prev_chainwork`, `pops_hardened`, `pops_bind_phi`, `bits`, `curtime`. The node computes the ring seed, `eta_phi`, and `eta_fiat_shamir` exactly as consensus will, so the staker uses them verbatim. `pops_bind_phi` tells the staker to build the V2 kernel (which binds the commitment image); it must match consensus or the produced block is rejected.
2.  For each locked commitment held by this wallet, check membership in the returned set.
3.  Construct a `blsct::ProofOfStake` with the hidden stake amount and blinding factor.
4.  Self-verify, then `submitblock`.

Flags: `navio-staker --help` on the binary matching your release.

## Unlock stake

```bash
navio-cli -testnet stakeunlock 5000
```

Releases 5,000 NAV from staking back to regular spendable UTXOs. Consensus enforces `nPePoSMinStakeAmount` on each locked output individually — you cannot partial-unlock below the minimum per commitment.

## Rewards

Rewards flow to sub-addresses in the staking pool (`account = -2`).

-   **Mainnet:** `nBLSCTBlockReward = 8 NAV` with `nPosTargetSpacing = 120 s`.
-   **Testnet / blsctregtest:** `nBLSCTBlockReward = 4 NAV` with `nPosTargetSpacing = 60 s`.
-   **Height 1 on BLSCT chains:** special initial supply mint via `nBLSCTFirstBlockReward`.

Inspect reward transactions with:

```bash
navio-cli -testnet listblscttransactions "*" 100 0 true
```

filter for `category: "stake"`.

## PoPS on BLSCT chains

On mainnet, testnet, and `blsctregtest`, the coinstake transaction does **not** reference a specific staked UTXO; `block.posProof` contains a set-membership proof + range proof that together show "one of these staked commitments is mine *and* my hidden stake satisfies the block's eligibility threshold" — without revealing which commitment or its amount. Plain `signet` and plain `regtest` do not use PoPS in the current chainparams. Protocol details: [BLSCT → PoPS](../blsct/pops.md).

## Cold staking

**Coming soon.** The design for Navio cold staking (spend key offline, staking authority delegated to a hot daemon) is not yet published. Track the [navio-core repo](https://github.com/nav-io/navio-core) for the reference implementation and this site for an operator guide once the protocol is finalised.

## Troubleshooting

| Symptom                                        | Likely cause                                                                  |
| ---------------------------------------------- | ----------------------------------------------------------------------------- |
| Staker logs "no eligible commitments"          | Wallet locked, stake not yet in `staked_commitments` set, or no staked outputs owned by this wallet |
| Wallet-unlock error on staker                  | Run `walletpassphrase <pw> <large-timeout> true` (`true` = staking-only)       |
| Staker restarts immediately                    | Usually RPC auth misconfig — check staker log + `rpcuser`/`rpcpassword`        |
| `submitblock` rejected                         | Verify `naviod` is at chain tip; stale templates produce PoPS proofs bound to the wrong parent |
| Blocks never mint                              | Check chain tip advancement (someone else is winning the lottery); your stake weight may be low relative to the set |

## Alternatives: dedicated staking pools

Third-party staking services may run validators on behalf of depositors. Vet any custodian; delegating funds carries custodial risk until the cold-staking design ships.
