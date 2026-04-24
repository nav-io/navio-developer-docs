# Mining & staking RPC

## Mining / block production

| Command                         | Purpose                                                      |
| ------------------------------- | ------------------------------------------------------------ |
| `getblocktemplate`              | Request a new block template. On PoPS networks this returns the `staked_commitments` set, `eta_fiat_shamir`, `eta_phi`, `prev_time`, and `modifier` needed by `navio-staker` to build a valid `posProof`. |
| `submitblock`                   | Submit a mined block                                          |
| `generatetoaddress <n> <addr>`  | Regtest-only — mine `n` blocks to `addr`                      |
| `getmininginfo`                 | Current template / network hashrate                           |

## Staking

| Command                         | Purpose                                                      |
| ------------------------------- | ------------------------------------------------------------ |
| [`stakelock`](../blsct.md#stakelock) | Lock NAV as stake                                          |
| [`stakeunlock`](../blsct.md#stakeunlock) | Release locked stake                                     |

Navio does **not** ship a `getstakinginfo` RPC. Verify staker operation from the [`navio-staker`](../../node/staking.md) process logs and from the receipt of `"stake"` category entries in `listblscttransactions`.

See [Node operator → Staking](../../node/staking.md) for an operational walkthrough.
