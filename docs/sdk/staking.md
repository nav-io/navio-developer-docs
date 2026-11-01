# Staking & cold staking

!!! note "navio-sdk 0.4.0+"
    Staked-output tracking, delegation and unstaking ship in navio-sdk **0.4.0**, which requires `@nav-io/navio-blsct` 1.3.0.

A light wallet can lock NAV as a **staked commitment** and delegate it to a third-party staker (cold staking): the staker can stake the output but never spend it, and the wallet keeps its spending keys and can unstake at any time. This mirrors navio-core's `delegatestake`, `listdelegations` and `stakeunlock` RPCs; see [Cold staking](../node/cold-staking.md) for the operator side.

## Staked balance

Staked commitments are recognised during sync and kept out of the spendable balance and coin selection:

```ts
await client.getStakedOutputs();   // WalletOutput[] with isStakedCommitment: true
await client.getStakedBalance();   // bigint, satoshis
client.getMinStakeAmount();        // bigint — chain minimum stake
```

`getMinStakeAmount()` returns the `minStakeAmount` config option if set, else the network default (10,000 NAV). Set `minStakeAmount` only for a chain with a different minimum, such as navio-core's `blsctregtest`.

## Delegate stake

```ts
const res = await client.delegateStake({
    amount:        20_000n * 100_000_000n,   // satoshis, at least getMinStakeAmount()
    delegateKey:   '<96-hex G1 point>',       // published by the staking operator
    rewardAddress: 'nav1...',                 // optional
});
console.log(res.txId);
```

`DelegateStakeOptions`:

| Field                | Type       | Notes                                                                                           |
| -------------------- | ---------- | ----------------------------------------------------------------------------------------------- |
| `amount`             | `bigint`   | Satoshis to stake; must reach the minimum stake.                                                |
| `delegateKey`        | `string`   | The staker's delegation public key, a non-identity G1 point (96 hex).                           |
| `rewardAddress`      | `string?`  | Where the staker is asked to pay rewards. Defaults (when omitted or empty) to the wallet's primary address. Advisory: the staker controls its own coinbase. |
| `selectedUtxos`      | `string[]?`| Fund the stake and fee from these outputs.                                                      |
| `randomBlindingKeys` | `boolean?` | See [Output authorship](sending.md#output-authorship).                                          |

The staked commitment goes to the wallet's staking sub-address (account `-2`) and carries an encrypted delegation payload for the staker. Each call adds a **new** staked commitment; unlike `delegatestake`, existing commitments are not folded in. A reward address with null keys is refused.

## List delegations

```ts
const delegations = await client.getStakeDelegations();
for (const d of delegations) {
    console.log(d.outputHash, d.amount, d.delegateKey, d.rewardAddress, d.blockHeight);
}
```

Like `listdelegations`, it reads the payload of each unspent staked commitment with the wallet's view key, from outputs sync already stored. It needs no extra state and works after a restore from seed. A delegation appears once its output confirms. A payload the wallet cannot open is skipped, with one warning per session.

## Unstake

```ts
// Unstake everything
await client.unstake();

// Partial: unlock 5,000 NAV from specific commitments, restake the rest
await client.unstake({
    stakedOutputs: ['<outputHash>', '<outputHash>'],
    amount: 5_000n * 100_000_000n,
});
```

| Field                | Default                              | Notes                                                                |
| -------------------- | ------------------------------------ | -------------------------------------------------------------------- |
| `stakedOutputs`      | every confirmed staked commitment    | Commitments to spend, by `outputHash`.                               |
| `amount`             | the whole of the spent commitments   | NAV to unlock, fee included.                                         |
| `randomBlindingKeys` | `false`                              | See [Output authorship](sending.md#output-authorship).              |

Unstaking spends the commitments, which also revokes their delegation. The unlocked NAV, less the fee, returns to the staking address as a normal output. A partial unstake stakes the remainder again; it must still reach the minimum stake. Unlike `stakeunlock`, the remainder **keeps** the delegation the spent commitments share; `unstake` refuses commitments that are delegated differently, or whose delegation the wallet cannot read. Only confirmed commitments can be unstaked.

## Upgrading to 0.4.0

-   `getBalance()` and `getUnspentOutputs()` no longer include staked commitments; before 0.4.0 they were counted as spendable NAV.
-   Existing databases are upgraded on open: SQLite gains an `is_staked_commitment` column (added and backfilled in one transaction) and the IndexedDB database moves to version 5.
-   Custom `IWalletDB` implementations must add `getOutputData(outputHash)`, set `isStakedCommitment` on every `WalletOutput`, and leave staked commitments out of `getBalance()` and `getUnspentOutputs()`.

## Regtest

`npm run test:cold-staking:regtest` in the navio-sdk repo runs delegation, listing and unstaking against a local `naviod -chain=blsctregtest`. It finds `naviod` on `PATH` by default.
