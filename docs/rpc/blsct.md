# BLSCT commands

All Navio-specific JSON-RPC commands. Covers tokens, NFTs, staking and delegation, consolidation, raw-transaction construction, balance proofs, recovery data, BLS message and output signing, audit keys, and wallet seed management.

This page is **automatically generated** by `scripts/extract-blsct-rpc.py` from [navio-core](https://github.com/nav-io/navio-core) source:

-   `src/blsct/wallet/rpc.cpp`
-   `src/blsct/tokens/rpc.cpp`
-   `src/blsct/range_proof/rpc.cpp`
-   `src/wallet/rpc/backup.cpp` (BLSCT-related commands only)

Run `navio-cli help <command>` on your node for the definitive help text — source may have evolved since the last documentation build. The tables below list top-level parameters only; `help` also shows the fields of nested objects and the result.

Commands below are sorted as they appear in source. Use the table of contents to jump.

## Quick index

| Category                  | Commands                                                                                                   |
| ------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Tokens & NFTs**         | `createtoken`, `createnft`, `minttoken`, `mintnft`, `gettoken`, `listtokens`, `listwallettokens`, `getwallettoken`, `gettokenbalance`, `getnftbalance`, `sendtokentoblsctaddress`, `sendnfttoblsctaddress` |
| **Sending**               | `sendtoblsctaddress`, `sendtokentoblsctaddress`, `sendnfttoblsctaddress`, `consolidate`                    |
| **Balance & outputs**     | `getblsctbalance`, `getbalanceforaddress`, `gettokenbalance`, `getnftbalance`, `listblsctunspent`, `getblsctoutput` |
| **Staking & delegation**  | `stakelock`, `stakeunlock`, `delegatestake`, `redelegatestake`, `compounddelegations`, `listdelegations`, `liststakingrewards` |
| **Raw transactions**      | `createblsctrawtransaction`, `fundblsctrawtransaction`, `signblsctrawtransaction`, `decodeblsctrawtransaction`, `unlockblsctoutpoint` |
| **Balance proofs**        | `createblsctbalanceproof`, `verifyblsctbalanceproof`                                                       |
| **Recovery / nonce**      | `getblsctrecoverydata`, `getblsctrecoverydatawithnonce`, `deriveblsctnonce`                               |
| **Signing**               | `signblsmessage`, `verifyblsmessage`, `signblsctoutput`                                                    |
| **HTLC / atomic swaps**   | `deriveblsctspendingkey`, `deriveblsctonetimekey`, `importblsctscript`                                     |
| **Seed / audit / backup** | `setblsctseed`, `getblsctseed`, `getblsctauditkey`, `dumpmnemonic`                                        |

!!! warning "`outputHash` is not a transaction id"
    The sending, minting, staking and delegation commands (`sendtoblsctaddress`, `sendtokentoblsctaddress`, `sendnfttoblsctaddress`, `createtoken`, `createnft`, `minttoken`, `mintnft`, `stakelock`, `stakeunlock`, `delegatestake`, `redelegatestake`, `compounddelegations`) return the **output hash** of one output they created, not a txid. Passing it to `gettransaction` does not find the transaction. Use [`gettxfromoutputhash`](categories/rawtransactions.md#output-hash-lookups) to get the `txid`. `liststakedcommitments` reports the same value as `tx_hash`.

!!! note "NFT token ids"
    Where a command takes a single token id string (`createblsctrawtransaction` outputs, and the RFQ/order commands on the [P2P messaging page](p2pmsg.md)), an NFT is written as the collection's 64-hex token id followed by `#<subid>`, for example `ba12…7edd#42`. NAV is the empty string.

!!! info "Removed: `listblscttransactions`"
    `listblscttransactions` was removed in v0.1.5 (it returned nothing). Use `listtransactions`, `listsinceblock` and `gettransaction`, which report BLSCT wallet transactions.

---

### `createnft`

Submits a transaction creating a NFT

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `metadata` | `OBJ_USER_KEYS` | yes | The NFT metadata |
| 2 | `max_supply` | `AMOUNT` | yes | The NFT max supply. |

**Examples**

```bash
curl --user user:pass --data-binary '{"jsonrpc":"1.0","id":"curl","method":"createnft","params":[{'name':'My NFT Collection'} 1000]}' -H "content-type: text/plain;" http://127.0.0.1:33677/
```

---

### `createtoken`

Submits a transaction creating a token.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `metadata` | `OBJ_USER_KEYS` | yes | The token metadata |
| 2 | `max_supply` | `AMOUNT` | yes | The token max supply. |

**Examples**

```bash
curl --user user:pass --data-binary '{"jsonrpc":"1.0","id":"curl","method":"createtoken","params":[{"name":"Token"} 1000]}' -H "content-type: text/plain;" http://127.0.0.1:33677/
```

---

### `listwallettokens`

Like listtokens, but wallet-aware: every token/NFT collection is reported with an
\"ismine\" flag saying whether THIS wallet created it (and can therefore mint it).
The check is read-only key derivation; nothing is broadcast. Requires the wallet
to be unlocked; a wallet without an HD seed (e.g. imported from a view key)
reports ismine=false for everything.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `mine_only` | `BOOL` | no (default `false`) | Only return tokens created by this wallet |

**Examples**

```bash
navio-cli listwallettokens
```

```bash
navio-cli listwallettokens true
```

---

### `getwallettoken`

Like gettoken, but wallet-aware: the token is reported with an \"ismine\" flag saying
whether THIS wallet created it (and can therefore mint it). The check is read-only key
derivation; nothing is broadcast. Requires the wallet to be unlocked; a wallet without an
HD seed (e.g. imported from a view key) reports ismine=false.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id |

**Examples**

```bash
navio-cli getwallettoken ba12afc43322f204fe6236b11a0f85b5d9edcb09f446176c73fe4abe99a17edd
```

---

### `minttoken`

Mints a certain amount of tokens to an address.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id. |
| 2 | `address` | `STR` | yes | The address where the tokens will be minted. |
| 3 | `amount` | `AMOUNT` | yes | The token amount to be minted. |

---

### `mintnft`

Mints a NFT to an address.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id. |
| 2 | `nft_id` | `AMOUNT` | yes | The nft id. |
| 3 | `address` | `STR` | yes | The address where the tokens will be minted. |
| 4 | `metadata` | `OBJ_USER_KEYS` | yes | The token metadata |

---

### `getblsctbalance`

Returns the total available BLSCT balance.
Only outputs the wallet can sign for are counted by default; pass
include_watchonly=true to also include outputs imported as watch-only
scripts (e.g. via importblsctscript), whose amount the wallet can
decrypt but cannot spend.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `minconf` | `NUM` | no (default `0`) | Only include transactions confirmed at least this many times. |
| 2 | `include_watchonly` | `BOOL` | no (default `"true for watch-only wallets, otherwise false"`) | Also include balance in watch-only addresses / scripts (see 'importblsctscript') |
| 3 | `avoid_reuse` | `BOOL` | no (default `true`) | (only available if avoid_reuse wallet flag is set) Do not include balance in dirty outputs; addresses are considered dirty if they have previously been used in a transaction. |

**Examples**

```bash
navio-cli getblsctbalance
```

```bash
navio-cli getblsctbalance 6
```

---

### `getbalanceforaddress`

Returns a breakdown of the balance held by a single address.
Spent outputs are excluded.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `address` | `STR` | yes | The address to query (transparent or BLSCT). |
| 2 | `minconf` | `NUM` | no (default `0`) | Minimum confirmations for an output to count towards 'trusted'. |
| 3 | `include_watchonly` | `BOOL` | no (default `"true for watch-only wallets, otherwise false"`) | Include balance from watch-only scripts (see 'importaddress' / 'importblsctscript'). |

**Examples**

```bash
navio-cli getbalanceforaddress "nv1..."
```

```bash
navio-cli getbalanceforaddress "nv1q..." 6
```

---

### `gettokenbalance`

Returns the total available balance of a token.
The available balance is what the wallet considers currently spendable, and is
thus affected by options which limit spendability such as -spendzeroconfchange.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id |
| 2 | `dummy` | `STR` | no | Remains for backward compatibility. Must be excluded or set to \"*\". |
| 3 | `minconf` | `NUM` | no (default `0`) | Only include transactions confirmed at least this many times. |
| 4 | `include_watchonly` | `BOOL` | no (default `"true for watch-only wallets, otherwise false"`) | Also include balance in watch-only addresses (see 'importaddress') |
| 5 | `avoid_reuse` | `BOOL` | no (default `true`) | (only available if avoid_reuse wallet flag is set) Do not include balance in dirty outputs; addresses are considered dirty if they have previously been used in a transaction. |

**Examples**

```bash
navio-cli gettokenbalance 0e8ba9acaef5a91e5933393baf0b1187fae81f158cd9455437378b1796fc893d
```

```bash
navio-cli gettokenbalance 0e8ba9acaef5a91e5933393baf0b1187fae81f158cd9455437378b1796fc893d "*" 6
```

---

### `getnftbalance`

Returns the NFTs owned from a collection.
The available balance is what the wallet considers currently spendable, and is
thus affected by options which limit spendability such as -spendzeroconfchange.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id from the collection |
| 2 | `dummy` | `STR` | no | Remains for backward compatibility. Must be excluded or set to \"*\". |
| 3 | `minconf` | `NUM` | no (default `0`) | Only include transactions confirmed at least this many times. |
| 4 | `include_watchonly` | `BOOL` | no (default `"true for watch-only wallets, otherwise false"`) | Also include balance in watch-only addresses (see 'importaddress') |
| 5 | `avoid_reuse` | `BOOL` | no (default `true`) | (only available if avoid_reuse wallet flag is set) Do not include balance in dirty outputs; addresses are considered dirty if they have previously been used in a transaction. |

**Examples**

```bash
navio-cli getnftbalance 0e8ba9acaef5a91e5933393baf0b1187fae81f158cd9455437378b1796fc893d
```

```bash
navio-cli getnftbalance 0e8ba9acaef5a91e5933393baf0b1187fae81f158cd9455437378b1796fc893d "*" 6
```

---

### `sendtoblsctaddress`

Send an amount to a given blsct address.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `address` | `STR` | yes | The BLSCT address to send to. |
| 2 | `amount` | `AMOUNT` | yes | The amount in to send. eg 0.1 |
| 3 | `memo` | `STR` | no (default `""`) | A memo used to store in the transaction.\n The recipient will see its value. |
| 4 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |
| 5 | `subtractfeefromamount` | `BOOL` | no (default `false`) | If true, the fee is deducted from the amount being sent so the recipient receives less than the requested amount and the wallet spends exactly the requested amount. |
| 6 | `comment_to` | `STR` | no (default `""`) | A wallet-local comment naming the person or organization the payment is to.\n Stored only in this wallet (surfaced by listtransactions as \"to\"); not sent on-chain. |

---

### `sendtokentoblsctaddress`

Send an amount to tokens to a given blsct address.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id. |
| 2 | `address` | `STR` | yes | The BLSCT address to send to. |
| 3 | `amount` | `AMOUNT` | yes | The amount in to send. eg 0.1 |
| 4 | `memo` | `STR` | no (default `""`) | A memo used to store in the transaction.\n The recipient will see its value. |
| 5 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

---

### `sendnfttoblsctaddress`

Send an NFT to a given blsct address.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id. |
| 2 | `nft_id` | `AMOUNT` | yes | The nft id. |
| 3 | `address` | `STR` | yes | The BLSCT address to send to. |
| 4 | `memo` | `STR` | no (default `""`) | A memo used to store in the transaction.\n The recipient will see its value. |
| 5 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

---

### `stakelock`

Lock an amount in order to stake it.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `amount` | `AMOUNT` | yes | The amount in to stake. eg 0.1 |
| 2 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

**Examples**

```bash
navio-cli stakelock 0.1
```

---

### `delegatestake`

Lock an amount for staking and delegate block production to a third-party staker.
The staked output carries an encrypted copy of its commitment opening addressed to
the delegate, so the delegate can produce blocks with it but can never spend or
unstake it. Block rewards are requested to be paid to reward_address; note this is
advisory: a delegate controls its own coinbase, so choose delegates you trust to
honor it. Existing stakes delegated with the same delegate key and reward address
are consolidated into the new output; other stakes are left untouched. Revoke at
any time with stakeunlock.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `amount` | `AMOUNT` | yes | The amount in to stake. eg 0.1 |
| 2 | `delegate_pubkey` | `STR_HEX` | yes | The delegate's 48-byte G1 delegation public key (hex), published by the staking operator. |
| 3 | `reward_address` | `STR` | no (default `""`) | BLSCT address the delegate should pay block rewards to. Defaults to a new address of this wallet. |
| 4 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

**Examples**

```bash
navio-cli delegatestake 100 "<delegate_pubkey_hex>"
```

---

### `stakeunlock`

Unlocks an staked amount.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `amount` | `AMOUNT` | yes | The amount in to unstake. eg 0.1 |
| 2 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

**Examples**

```bash
navio-cli stakeunlock 0.1
```

---

### `listdelegations`

List this wallet's active stake delegations: every unspent staked output that
carries a delegation payload, with the delegate key and reward address recovered
from the chain. When a delegation's reward address belongs to this wallet, the
coinbase rewards received on it are summed so the owner can check the delegate
is honoring the reward address.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listdelegations
```

---

### `liststakingrewards`

List the coinbase (staking) rewards this wallet has received, grouped by the
address they were paid to. Entries whose address is the reward address of an
active delegation are flagged from_delegation; the remaining entries are the
wallet's own (non-delegated) staking rewards, e.g. from running navio-staker
with this wallet.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli liststakingrewards
```

---

### `redelegatestake`

Move existing stake delegations to a different delegate and/or reward address in a
single transaction. The delegated commitments stay staked the whole time: the old
delegated outputs are spent directly into a new staked output carrying the new
delegation payload, so there is no separate unlock/re-lock step and no gap in stake
continuity. Only delegations to from_delegate_pubkey are moved; other stakes are
left untouched.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `from_delegate_pubkey` | `STR_HEX` | yes | The delegate key the stakes are currently delegated to. |
| 2 | `delegate_pubkey` | `STR_HEX` | yes | The new delegate's 48-byte G1 delegation public key (hex). May equal from_delegate_pubkey to only change the reward address. |
| 3 | `reward_address` | `STR` | no (default `""`) | BLSCT address the new delegate should pay block rewards to. Defaults to the reward address of the delegations being moved. |
| 4 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

**Examples**

```bash
navio-cli redelegatestake "<old_pubkey_hex>" "<new_pubkey_hex>"
```

---

### `compounddelegations`

Re-delegate accumulated rewards: fold the wallet's spendable balance (minus a fee
margin) into an existing stake delegation. Block rewards paid to this wallet do not
auto-compound -- the spend key would need to be online for that -- so run this
periodically (e.g. from cron) to keep delegated stake growing.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `delegate_pubkey` | `STR_HEX` | no (default `""`) | The delegation to compound into. May be omitted when the wallet has exactly one delegation identity. |
| 2 | `min_amount` | `AMOUNT` | no (default `1`) | Do nothing (return null) while the spendable balance is below this amount. Independently of it, 1 NAV of the spendable balance is always held back as a fee margin. |

**Examples**

```bash
navio-cli compounddelegations
```

---

### `consolidate`

Merge many small spendable outputs into fewer large ones, paid back to this wallet.
Wallets that accumulate many small outputs (e.g. PoS staking rewards) cannot spend them all
in a single transaction once they exceed the per-transaction input limit. Run this to combine
the smallest outputs; each consolidation transaction merges up to the per-transaction input
cap. Like plain sends, each consolidation is aggregated with fee-0 cover candidates from the
node's p2pmsg pool when any are available (disable with -aggregatesends=0), so its inputs and
output are merged with unrelated cover spends. Cover is at most  single-input spends,
so in a consolidation of many outputs most inputs are still attributable to this wallet.
If a transaction after the first fails, the call stops and returns the ids already
broadcast (the failure is logged); it raises an error only when none went out.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `max_txs` | `NUM` | no | Maximum number of consolidation transactions to create this call (default 1). |
| 2 | `max_inputs` | `NUM` | no | Maximum outputs to merge per transaction (default and hard cap: the per-transaction input limit). |

**Examples**

```bash
navio-cli consolidate 5
```

---

### `listblsctunspent`

Returns array of unspent transaction outputs
with between minconf and maxconf (inclusive) confirmations.
Optionally filter to only include txouts paid to specified addresses.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `minconf` | `NUM` | no (default `1`) | The minimum confirmations to filter |
| 2 | `maxconf` | `NUM` | no (default `9999999`) | The maximum confirmations to filter |
| 3 | `addresses` | `ARR` | no (default `UniValue::VARR`) | The navio addresses to filter |
| 4 | `query_options` | `OBJ_NAMED_PARAMS` | no |  |

**Examples**

```bash
navio-cli listblsctunspent
```

```bash
navio-cli listblsctunspent 6 9999999 '[]' '{ "minimumAmount": 0.005 }'
```

---

### `setblsctseed`

Set or generate a new BLSCT wallet seed. Non-BLSCT wallets will not be upgraded to being a BLSCT wallet. Wallets that are already
BLSCT will have a new BLSCT seed set so that new keys added to the keypool will be derived from this new seed.

Note that you will need to MAKE A NEW BACKUP of your wallet after setting the BLSCT wallet seed.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `seed` | `STR` | no (default `"random seed"`) | The WIF private key to use as the new HD seed.\n |

**Examples**

```bash
navio-cli setblsctseed
```

```bash
navio-cli setblsctseed
```

---

### `createblsctbalanceproof`

Creates a zero-knowledge proof that the wallet has at least the specified balance

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `amount` | `AMOUNT` | yes | The minimum balance to prove |
| 2 | `additional_commitment` | `STR` | no | The additional commitment to use for the proof signature |

**Examples**

```bash
navio-cli createblsctbalanceproof 1.0 "order id: 100"
```

---

### `createblsctrawtransaction`

Create a unsigned transaction spending the given inputs and creating new outputs.
Returns hex-encoded raw unsigned transaction.
Note that the transaction's inputs are not signed, and
it is not stored in the wallet or transmitted to the network.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `inputs` | `ARR` | yes | A json array of json objects |
| 2 | `outputs` | `ARR` | yes | A json array with outputs (key-value pairs) |
| 3 | `type` | `STR` | no (default `""`) | Transaction type: \"normal\", \"create_token\", \"mint_token\", or \"mint_nft\" |

**Examples**

```bash
navio-cli createblsctrawtransaction "[{\"outid\":\"myoutid\",\"value\":1000000,\"gamma\":\"1234567890abcdef\",\"spending_key\":\"abcdef1234567890\"}]" "[{\"address\":\"address\",\"amount\":1000000,\"memo\":\"memo\",\"token_id\":\"tokenid\"}]"
```

```bash
navio-cli createblsctrawtransaction "[{\"outid\":\"myoutid\"}]" "[{\"address\":\"address\",\"amount\":1000000}]"
```

---

### `fundblsctrawtransaction`

Add inputs to a BLSCT transaction until it has enough value to cover outputs and fee.
The funded transaction fee is raised to satisfy the consensus rule:
fee ≥ transaction weight × the network's blsct default fee rate (see chainparams).
If estimate_fee is true, the RPC targets that minimum fee (optionally bumped by fee). When false,
fee is explicit (default 1000000) but still bumped if below the consensus minimum.
If lock_unspents is true, selected inputs are locked. Use unlockblsctoutpoint to unlock them.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The hex string of the raw transaction |
| 2 | `changeaddress` | `STR` | no | The BLSCT address to receive the change |
| 3 | `lock_unspents` | `BOOL` | no (default `false`) | Lock selected unspent outputs |
| 4 | `fee` | `NUM` | no | Absolute fee navoshis. With estimate_fee true: optional minimum floor; omit for weight-only estimate. Otherwise defaults to 1000000 |
| 5 | `estimate_fee` | `BOOL` | no (default `false`) | Estimate fee from weight × consensus rate (instead of explicit default or fee argument) |

**Examples**

```bash
navio-cli fundblsctrawtransaction "hexstring"
```

```bash
navio-cli fundblsctrawtransaction "hexstring" "changeaddress"
```

---

### `unlockblsctoutpoint`

Unlock a BLSCT outpoint that was previously locked for funding.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `outpoint_hash` | `STR_HEX` | yes | The output outpoint hash |

**Examples**

```bash
navio-cli unlockblsctoutpoint "outpoint_hash"
```

---

### `signblsctrawtransaction`

Signs a BLSCT raw transaction by adding BLSCT signatures.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The transaction hex string |

**Examples**

```bash
curl --user user:pass --data-binary '{"jsonrpc":"1.0","id":"curl","method":"signblsctrawtransaction","params":["hexstring"]}' -H "content-type: text/plain;" http://127.0.0.1:33677/
```

---

### `decodeblsctrawtransaction`

Decode a BLSCT raw transaction and return a JSON object describing the transaction structure.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The transaction hex string |

**Examples**

```bash
navio-cli decodeblsctrawtransaction "hexstring"
```

---

### `getblsctrecoverydata`

Get BLSCT recovery data for transaction output(s)

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `txid_or_hex` | `STR` | yes | The transaction id, raw transaction hex, or output outpoint hash |
| 2 | `vout` | `NUM` | no | The output index. If omitted, shows data for all outputs. Ignored when an outpoint hash is provided. |

**Examples**

```bash
navio-cli getblsctrecoverydata "mytxid"
```

```bash
navio-cli getblsctrecoverydata "mytxid" 1
```

---

### `getblsctrecoverydatawithnonce`

Get BLSCT recovery data for outputs in a transaction using a specified shared public nonce.
Accepts a transaction hex string or an output outpoint hash.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The transaction hex string or output outpoint hash |
| 2 | `nonce` | `STR_HEX` | yes | The shared public nonce to use for recovery (48-byte hex public key) |
| 3 | `vout` | `NUM` | no | If specified, only return data for this output index. Ignored when an outpoint hash is provided. |

**Examples**

```bash
navio-cli getblsctrecoverydatawithnonce "hexstring" "nonce"
```

```bash
navio-cli getblsctrecoverydatawithnonce "hexstring" "nonce" 1
```

---

### `deriveblsctnonce`

Derive the shared public nonce for a BLSCT output from a destination address and blinding key.
This can be used together with getblsctrecoverydatawithnonce for outputs whose amount was blinded
against the destination's public view key, including HTLC outputs constructed from address_a.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `blinding_key` | `STR_HEX` | yes | The 32-byte blinding key (hex) used when creating the output |
| 2 | `address` | `STR` | yes | The BLSCT destination address used to derive the shared public nonce |

**Examples**

```bash
navio-cli deriveblsctnonce "0102030405060708091011121314151617181920212223242526272829303132" "rnv1..."
```

---

### `signblsmessage`

Sign a message using a BLS private key.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `private_key` | `STR_HEX` | yes | The BLS private key in hex format |
| 2 | `message` | `STR` | yes | The message to sign |

**Examples**

```bash
navio-cli signblsmessage "private_key_hex" "Hello, world!"
```

---

### `verifyblsmessage`

Verify a BLS message signature.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `public_key` | `STR_HEX` | yes | The BLS public key in hex format |
| 2 | `message` | `STR` | yes | The message that was signed |
| 3 | `signature` | `STR_HEX` | yes | The signature in hex format |

**Examples**

```bash
navio-cli verifyblsmessage "public_key_hex" "Hello, world!" "signature_hex"
```

---

### `deriveblsctspendingkey`

Derive the private spending key for an HTLC/atomic-swap output.
Given the blinding key used when creating the output and a BLSCT address owned by this wallet,
returns the private spending key needed to spend via the corresponding script branch.

NOTE: this RPC only works correctly with the wallet's top-level (default) BLSCT address.
Sub-addresses use a different spend-key point (D = sk + H(vk,i,j)·G) and will not derive
the correct spending key with this call.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `blinding_key` | `STR_HEX` | yes | The 32-byte blinding key (hex) used when creating the HTLC output |
| 2 | `address` | `STR` | yes | The BLSCT address to derive the spending key for (must be owned by this wallet) |

**Examples**

```bash
navio-cli deriveblsctspendingkey "0102030405060708091011121314151617181920212223242526272829303132" "rnv1..."
```

---

### `deriveblsctonetimekey`

Stateless derivation of the one-time key material for a BLSCT output sent to an
externally constructed destination (view point V = view_key*G1, spend point S).
An output created for such a destination carries ephemeralKey = b*G1 (b = the
sender's blinding key) and one-time spending key S + H(b*V)*G1. Given the private
view scalar and the output's ephemeral key this returns the shared point
b*V (the recovery nonce for getblsctrecoverydatawithnonce), the derived scalar
tweak H(b*V) with its public point, and the expected view tag. If the private
spend scalar is also provided, the full one-time private spending key
spend_key + H(b*V) is returned, suitable for the spending_key input field of
createblsctrawtransaction.
Wallet keys are not consulted: intended for jointly derived destinations (e.g.
atomic-swap outputs locked to a combined key) that no wallet owns.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `view_key` | `STR_HEX` | yes | The 32-byte private view scalar (hex) of the destination |
| 2 | `ephemeral_key` | `STR_HEX` | yes | The 48-byte ephemeral key (hex) of the output (blsctData.ephemeralKey) |
| 3 | `spend_key` | `STR_HEX` | no | The 32-byte private spend scalar (hex) of the destination; when given, the full one-time private key is returned |

**Examples**

```bash
navio-cli deriveblsctonetimekey "<view scalar hex>" "<ephemeral key hex>"
```

---

### `getblsctoutput`

Look up a BLSCT output by its output hash.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `output_hash` | `STR_HEX` | yes | The output hash to look up. |

**Examples**

```bash
curl --user user:pass --data-binary '{"jsonrpc":"1.0","id":"curl","method":"getblsctoutput","params":["a685e520f85d111a6c55bd2b8226f6b916a3bcdd3b549c75e0abddc55df70951"]}' -H "content-type: text/plain;" http://127.0.0.1:33677/
```

---

### `signblsctoutput`

Sign an arbitrary message with the blinding key of a BLSCT output this wallet created.

The signature proves that this wallet built the output -- nothing else on chain identifies
the sender of a confidential payment. It says nothing about who owns the funds now, which is
exactly what a refund claim needs: the person who paid is the person entitled to the reversal.

Only outputs created by a wallet running this feature can be signed for. Outputs created
earlier used a random blinding scalar that was discarded and is gone for good.

What is signed is sha256(\"navio-blsct-output-auth/v1\" || message), NOT the message itself.
The domain prefix is what keeps this from being a signing oracle for a consensus key: every
BLSCT output carries a signature under this same key over its 32-byte output hash, so signing
caller-chosen bytes would let a caller obtain one. Verifiers must hash the same way.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `txid` | `STR_HEX` | yes | The id of the transaction holding the output. |
| 2 | `vout` | `NUM` | yes | The index of the output within that transaction. |
| 3 | `message` | `STR` | yes | The message to sign. |

**Examples**

```bash
navio-cli signblsctoutput "a685e520f85d111a6c55bd2b8226f6b916a3bcdd3b549c75e0abddc55df70951" 0 "navio-hl-refund/v1|<txid>|<vout>|<note>"
```

---

### `gettoken`

Returns an object containing information about a token.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `token_id` | `STR_HEX` | yes | The token id |

**Examples**

```bash
navio-cli gettoken ba12afc43322f204fe6236b11a0f85b5d9edcb09f446176c73fe4abe99a17edd
```

---

### `listtokens`

Returns an array containing the tokens list.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli listtokens
```

---

### `verifyblsctbalanceproof`

Verifies a zero-knowledge balance proof

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `proof` | `STR_HEX` | yes | The serialized balance proof |
| 2 | `additional_commitment` | `STR` | no | The additional commitment to use for the proof signature verification |

**Examples**

```bash
navio-cli verifyblsctbalanceproof "<hex>"
```

---

### `getblsctseed`

Dumps the BLSCT wallet seed, which can be used to reconstruct the wallet.
Note: This command is only compatible with BLSCT wallets.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli getblsctseed
```

---

### `getblsctauditkey`

Dumps the BLSCT wallet audit key, which can be used to observe the wallet history without being able to spend the transactions.
Note: This command is only compatible with BLSCT wallets.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli getblsctauditkey
```

---

### `dumpmnemonic`

Dumps the BLSCT wallet mnemonic phrase (BIP-39), which can be used to reconstruct the wallet.
The mnemonic can only be retrieved from wallets created with a BIP-39 mnemonic.
Wallets imported from a raw seed/master key, and wallets created before mnemonic backup
was stored, have no mnemonic to export: the mnemonic cannot be derived from the seed.
Use 'getblsctseed' to back up those wallets instead.
If the wallet was created with a BIP-39 mnemonic passphrase, the passphrase is NOT included
and must be supplied separately when restoring the wallet.
Note: This command is only compatible with BLSCT wallets.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |

**Examples**

```bash
navio-cli dumpmnemonic
```

---

### `importblsctscript`

Import a BLSCT script for watching.
Supports two modes via the \"type\" field in the script descriptor object:
\"atomic_swap\" - reconstruct an HTLC script from pre-agreed swap parameters.
\"raw\"         - import an arbitrary script from its hex encoding.

The wallet will detect matching on-chain outputs during block scanning.
Note: Use \"getwalletinfo\" to query the scanning progress.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `script_descriptor` | `OBJ` | yes | Script descriptor |
| 2 | `rescan` | `BOOL` | no (default `true`) | Rescan the blockchain after import |
| 3 | `start_height` | `NUM` | no | Block height where the rescan should start. Requires rescan=true. |

**Examples**

```bash
navio-cli importblsctscript '{"type":"raw","script":"51"}'
```

```bash
navio-cli importblsctscript '{"type":"raw","script":"51"}' true 120
```

---

