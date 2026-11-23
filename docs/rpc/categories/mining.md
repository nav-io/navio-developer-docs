# Mining & staking RPC

## Mining / block production

| Command                         | Purpose                                                      |
| ------------------------------- | ------------------------------------------------------------ |
| `getblocktemplate`              | Request a new block template. On PoPS networks this returns the `staked_commitments` set, `eta_fiat_shamir`, `eta_phi`, `prev_time`, and `modifier` needed by `navio-staker` to build a valid `posProof`. |
| `submitblock`                   | Submit a mined block                                          |
| `generatetoblsctaddress <n> <addr> [maxtries] [signetkey]` | Mine `n` proof-of-work blocks paying a BLSCT address. Only possible up to the network's last proof-of-work height. On signet (v0.3.0+) `signetkey` is required (see below) |
| `generatetoaddress`, `generatetodescriptor`, `generateblock` | Transparent coinbase. Refused on mainnet, testnet, `blsctregtest` and (v0.3.0+) signet; usable on `regtest` |
| `getmininginfo`                 | Height, last template weight and tx count, mempool size, chain (no hashrate or difficulty fields since v0.1.5) |

!!! note "`maxtries` and short results"
    For `generatetoaddress`, `generatetoblsctaddress` and `generatetodescriptor`, `maxtries` is one budget of nonces for the whole call, not per block. When it runs out (or the node shuts down) the call returns the hashes mined so far, which can be **fewer than requested**, rather than an error. From v0.3.0, `generatetoaddress` and `generatetoblsctaddress` refuse a negative `maxtries` ("JSON integer out of range"), as `generatetodescriptor` already did, instead of wrapping it into an effectively unlimited value; values above 2147483647 are now accepted.

On a BLSCT-only network the refusal message for the transparent generate RPCs names `generatetoblsctaddress` only while the chain is still below the last proof-of-work height; above it, blocks must be proof-of-stake.

!!! info "Signet block signing (new in v0.3.0)"
    Every signet block must be signed for the network's `-signetchallenge`, proof-of-stake blocks included. `generatetoblsctaddress` takes the signing key as its fourth argument `signetkey`, a private key as 32 bytes of hex. Without it the call fails with "Signet blocks must be signed: pass the signetkey argument" (`RPC_INVALID_PARAMETER`); a malformed key fails with "Invalid signetkey" (`RPC_INVALID_ADDRESS_OR_KEY`); passing it on any other network fails with "signetkey is only used on signet". `navio-staker` takes the same key as `-signetblockkey`. See [Networks → Signet](../../concepts/networks.md#signet).

## Staking

| Command                         | Purpose                                                      |
| ------------------------------- | ------------------------------------------------------------ |
| [`stakelock`](../blsct.md#stakelock) | Lock NAV as stake                                          |
| [`stakeunlock`](../blsct.md#stakeunlock) | Release locked stake                                     |
| [`delegatestake`](../blsct.md#delegatestake) / [`redelegatestake`](../blsct.md#redelegatestake) / [`compounddelegations`](../blsct.md#compounddelegations) | Delegated (cold) staking |
| [`listdelegations`](../blsct.md#listdelegations) | This wallet's active delegations. From v0.3.0 each entry also carries `commitment`, the staked commitment in the encoding `liststakedcommitments` uses |
| [`liststakingrewards`](../blsct.md#liststakingrewards) | Staking rewards received by this wallet |
| `liststakedcommitments`        | This wallet's staked commitments. `tx_hash` is the commitment's output hash, not a txid: use `gettxfromoutputhash` to find the transaction |

`stakelock`, `stakeunlock` and the delegation commands return an `outputHash`, not a txid.

Navio does **not** ship a `getstakinginfo` RPC. Verify staker operation from the [`navio-staker`](../../node/staking.md) process logs and from `"stake"` category entries in `listtransactions`.

See [Node operator → Staking](../../node/staking.md) for an operational walkthrough.
