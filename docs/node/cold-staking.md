# Cold staking

Cold staking splits staking authority from spending authority: the **staking (delegation) key stays hot** on the machine that produces blocks, while the **spend key stays cold** — in a wallet that can remain offline. A compromised staking box loses you nothing but block production; the principal is untouchable without the spend key.

This is the most secure way to stake, and it works in two deployments — both with **no consensus changes**:

- **Self-operated (recommended):** run `navio-staker` on your own server with a delegation key you generated yourself, and delegate your stake to it from your wallet. Your spend key never touches the server.
- **Delegated to an operator:** point the same delegation at a third-party operator's published key. The operator produces blocks with your coins but can never spend or unstake them.

Available since **v0.1.7**. Protocol background: [BLSCT → Proof-of-Private-Stake](../blsct/pops.md); hot-wallet staking: [Staking](staking.md). For the strongest setup, keep even the delegating wallet's spend key offline with [air-gapped signing](../guides/airgap-signing.md) in Navio Electrum - the full recipe is in [Best-practice secure setup](../guides/secure-setup.md).

## Why it works

PoPS block production only needs the *opening* of a staked Pedersen commitment — its `(value, gamma)` pair. It never needs the spending key, which is only required to spend or unstake the output. Cold staking exploits exactly this split:

- The staked output carries a `DATA` predicate — a consensus no-op — containing the commitment's opening and a reward address, encrypted to the operator's delegation key (ECDH + ChaCha20-Poly1305, fresh ephemeral key per delegation).
- The operator trial-decrypts the chain's staked outputs, verifies each recovered opening against the on-chain commitment, and stakes with the standard PoPS path.
- The payload also carries an owner section encrypted under the output's BLSCT nonce (the same secret the wallet already uses to recover amounts), so the owner wallet can re-derive all its delegations **from the chain alone** — delegations survive a restore from seed.

## Trust model

| Party    | Can                                                                                                    | Cannot                                                                  |
| -------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| Operator | produce blocks with the delegated stake; see the delegated outputs' amounts; redirect *future* rewards | spend or unstake the principal; see anything else in the owner's wallet |
| Owner    | revoke unilaterally at any time; keep the spend key offline                                            | cryptographically force the reward destination                          |

Caveats:

- **Reward routing is advisory.** The operator builds its own coinbase; nothing on-chain forces it to honor the delegated reward address or the agreed fee. Monitor payouts (`listdelegations` shows rewards received per delegation) and revoke misbehaving operators. Operators compete on reputation.
- **No view keys are shared.** The operator learns only the `(value, gamma)` openings of the outputs explicitly delegated to it.
- **Delegated outputs are publicly distinguishable** (they carry a predicate), though the amount and the operator's identity stay hidden from third parties.
- **Consolidation is delegation-aware.** Stake operations only fold commitments sharing the same delegation identity (delegate key + reward address). A `stakelock` never touches a delegated stake and vice versa, so a delegation is never silently revoked or extended.

## Self-operated cold staking

Run your own staker with the security profile of a cold wallet:

```bash
# on the staking server: generate your own delegation key pair
navio-staker -gendelegationkey

# in your wallet (Navio Core or Navio Electrum), delegate to your own key:
navio-cli delegatestake 10000 <your_delegation_pubkey>

# on the staking server: stake the delegation, no wallet needed
navio-staker -delegated -delegationkeyfile=/etc/navio/delegation.key
```

The server holds only the delegation key. If it is compromised, the attacker can produce blocks with your stake (and redirect *future* rewards) until you notice and `redelegatestake` or revoke — the principal and past rewards are safe behind the offline spend key. Compare this with [hot-wallet staking](staking.md), where the staking machine holds a wallet that must be able to open its outputs.

Navio Electrum supports this flow directly: `Wallet > Staking > Stake…` with your delegation key in the *Operator delegation key* field.

## Owner workflow

### Delegate

```bash
# operator publishes its delegation public key; then:
navio-cli -testnet delegatestake 10000 <operator_pubkey> [reward_address]
```

Locks 10,000 NAV as a normal staked commitment carrying the encrypted delegation payload. `reward_address` defaults to a fresh address of the wallet. Consensus minimum stake applies (`10,000 NAV` on mainnet/testnet, `100 NAV` on `blsctregtest`).

### Audit

```bash
navio-cli -testnet listdelegations
```

Recovers every active delegation from the chain: staked output hash, amount, confirmations, delegate key, reward address — and, when the reward address belongs to this wallet, the total coinbase rewards received on it. That last field is the "is my operator actually paying me" check.

```bash
navio-cli -testnet liststakingrewards
```

All coinbase rewards the wallet has received, grouped by address, flagging which addresses belong to an active delegation — tracks delegated and own (non-delegated) staking rewards in one place.

`getbalances` reports the delegated portion of the staked balance separately as `delegated_staked_commitment_balance`.

### Change operator or reward address

```bash
navio-cli -testnet redelegatestake <old_operator_pubkey> <new_operator_pubkey> [new_reward_address]
```

Spends the delegated commitments directly into a new staked output carrying the new payload — a single transaction, and the stake never leaves the staking set (no unlock/re-lock gap). Pass the same operator key with a new `reward_address` to only reroute rewards.

### Compound rewards

Rewards land in the owner wallet as ordinary spendable outputs; they cannot auto-compound because the spend key is offline. Fold them back into the delegation periodically (e.g. from cron):

```bash
navio-cli -testnet compounddelegations            # single delegation
navio-cli -testnet compounddelegations <operator_pubkey> 50   # min 50 NAV before acting
```

Stakes the spendable balance (minus a fee margin) into the existing delegation; returns `null` when below `min_amount`.

### Revoke

```bash
navio-cli -testnet stakeunlock 10000
```

Requires the spend key. The commitment leaves the staked set and the delegation dies with it. `redelegatestake` and `delegatestake` work again afterwards — the delegation is bound to the output, not the wallet or the operator key.

## Operator workflow

### Generate and publish a delegation key

```bash
navio-staker -gendelegationkey
```

Prints a key pair. Keep the private key secret; publish the public key so owners can delegate to you.

### Run the wallet-less staker

```bash
navio-staker -testnet -delegated -delegationkeyfile=/etc/navio/delegation.key \
    -operatoraddress=<your_blsct_address> -operatorfee=1000 \
    -delegationrefresh=300 -statsfile=/var/lib/navio/delegations.json
```

No wallet is needed on the staking machine. The staker:

1. Scans the chain's staked outputs (`liststakedcommitmentsdata` — cached per chain tip on the node, so polling is cheap) every `-delegationrefresh` seconds.
2. Trial-decrypts each delegation payload with the delegation key and verifies the opening against the on-chain commitment.
3. Stakes the tracked delegations most-confirmed-first through the standard PoPS path. Block rewards go to each delegation's reward address; with `-operatorfee` (basis points), that share goes to `-operatoraddress` via a second coinbase output.

Flags:

| Flag                        | Purpose                                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------------------ |
| `-delegated`                | Delegated (cold-staking operator) mode; stake third-party delegations instead of a local wallet. |
| `-delegationkeyfile=<path>` | Read the delegation private key from a file (preferred — a key passed with `-delegationkey` is visible in the process list). |
| `-delegationkey=<hex>`      | The delegation private key inline. Mutually exclusive with `-delegationkeyfile`.                 |
| `-operatoraddress=<addr>`   | BLSCT address receiving the `-operatorfee` share of delegated block rewards.                     |
| `-operatorfee=<bps>`        | Operator fee in basis points `[0, 10000]` (default 0).                                           |
| `-delegationrefresh=<sec>`  | Chain rescan interval for new delegations (default 300).                                         |
| `-statsfile=<path>`         | Maintain per-delegation accounting as JSON: blocks accepted/rejected per delegation, last block hash/time, reward address. |

## RPC quick reference

| Call                                                            | Side     | Purpose                                                        |
| --------------------------------------------------------------- | -------- | -------------------------------------------------------------- |
| `delegatestake amount pubkey [reward_address]`                   | owner    | Lock and delegate a stake.                                     |
| `listdelegations`                                                | owner    | Audit active delegations + rewards received.                   |
| `liststakingrewards`                                             | owner    | Coinbase rewards by address, delegated vs own.                 |
| `redelegatestake from_pubkey pubkey [reward_address]`            | owner    | Move delegations in one tx, no staking gap.                    |
| `compounddelegations [pubkey] [min_amount]`                      | owner    | Fold spendable rewards back into a delegation.                 |
| `stakeunlock amount`                                             | owner    | Revoke (spend key required).                                   |
| `liststakedcommitmentsdata`                                      | node     | Public scan of staked outputs + predicates; operator discovery. |
| `getblocktemplate {"coinbasedest": A, "coinbasefeedest": B, "coinbasefeebps": N}` | node | Coinbase split: `N/10000` of the reward to `B`, rest to `A`. |

!!! note "Version availability"
    The core flow — `delegatestake`, `liststakedcommitmentsdata`, `navio-staker -delegated`, the operator fee split, revocation — ships in **v0.1.7**. The usability layer — `listdelegations`, `liststakingrewards`, `redelegatestake`, `compounddelegations`, `-delegationkeyfile`, `-statsfile`, per-tip scan caching and `height`/`confirmations` fields — is merged on master ([PR #321](https://github.com/nav-io/navio-core/pull/321)) and lands in the next release.

## Troubleshooting

| Symptom                                             | Likely cause                                                                                     |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Staker logs `Tracking 0 delegated commitment(s)`    | No delegation addressed to this key on-chain yet, wrong delegation key, or delegation not confirmed. |
| `Delegation ... opening that does not match`        | Corrupt or forged payload — the staker refuses to burn slots on unprovable stakes. Owner should re-delegate. |
| Rewards not arriving at the reward address          | Operator not honoring the delegation (routing is advisory). Verify with `listdelegations`, then `redelegatestake` to a different operator or revoke. |
| `delegatestake` fails with "A minimum of ..."       | Amount below `nPePoSMinStakeAmount` for the chain.                                               |
| Owner wallet shows the stake but no delegation      | Wallet built before v0.1.7, or the output's payload was created by different software — check `liststakedcommitmentsdata` for the predicate. |
