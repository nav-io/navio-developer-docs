# BLSCT commands

All Navio-specific JSON-RPC commands. Covers tokens, NFTs, staking, raw-transaction construction, balance proofs, recovery data, BLS message signing, audit keys, and wallet seed management.

This page is **automatically generated** by `scripts/extract-blsct-rpc.py` from [navio-core](https://github.com/nav-io/navio-core) source:

-   `src/blsct/wallet/rpc.cpp`
-   `src/blsct/tokens/rpc.cpp`
-   `src/blsct/range_proof/rpc.cpp`
-   `src/wallet/rpc/backup.cpp` (BLSCT-related commands only)

Run `navio-cli help <command>` on your node for the definitive help text — source may have evolved since the last documentation build.

Commands below are sorted as they appear in source. Use the table of contents to jump.

## Quick index

| Category                  | Commands                                                                                                   |
| ------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Tokens & NFTs**         | `createtoken`, `createnft`, `minttoken`, `mintnft`, `gettoken`, `listtokens`, `gettokenbalance`, `getnftbalance`, `sendtokentoblsctaddress`, `sendnfttoblsctaddress` |
| **Sending**               | `sendtoblsctaddress`, `sendtokentoblsctaddress`, `sendnfttoblsctaddress`                                 |
| **Balance & outputs**     | `getblsctbalance`, `gettokenbalance`, `getnftbalance`, `listblsctunspent`, `listblscttransactions`, `getblsctoutput` |
| **Staking**               | `stakelock`, `stakeunlock`                                                                                 |
| **Raw transactions**      | `createblsctrawtransaction`, `fundblsctrawtransaction`, `signblsctrawtransaction`, `decodeblsctrawtransaction`, `unlockblsctoutpoint` |
| **Balance proofs**        | `createblsctbalanceproof`, `verifyblsctbalanceproof`                                                       |
| **Recovery / nonce**      | `getblsctrecoverydata`, `getblsctrecoverydatawithnonce`, `deriveblsctnonce`                               |
| **BLS messages**          | `signblsmessage`, `verifyblsmessage`                                                                       |
| **HTLC / atomic swaps**   | `deriveblsctspendingkey`, `importblsctscript`                                                              |
| **Seed / audit / backup** | `setblsctseed`, `getblsctseed`, `getblsctauditkey`, `dumpmnemonic`                                        |

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

Returns the total available balance.
The available balance is what the wallet considers currently spendable, and is
thus affected by options which limit spendability such as -spendzeroconfchange.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `minconf` | `NUM` | no (default `0`) | Only include transactions confirmed at least this many times. |
| 2 | `include_watchonly` | `BOOL` | no (default `"true for watch-only wallets, otherwise false"`) | Also include balance in watch-only addresses (see 'importaddress') |
| 3 | `avoid_reuse` | `BOOL` | no (default `true`) | (only available if avoid_reuse wallet flag is set) Do not include balance in dirty outputs; addresses are considered dirty if they have previously been used in a transaction. |

**Examples**

```bash
navio-cli getblsctbalance
```

```bash
navio-cli getblsctbalance "*" 6
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
| 5 | `subtractfeefromamount` | `BOOL` | no (default `false`) | If true, the fee is deducted from `amount` — the recipient receives less than requested and the wallet spends exactly `amount`. |
| 6 | `comment_to` | `STR` | no (default `""`) | Wallet-local comment naming the person/organization the payment is to. Stored only on the sender's wallet (surfaced by `listtransactions`), never sent on-chain. |

The recipient-visible `memo` is also mirrored into the sender's wallet-local `comment` field. `sendtoaddress` routes to this command for BLSCT wallets and forwards its `comment` argument.

!!! note "Added in 0.1.3"
    `subtractfeefromamount` and `comment_to` were added in navio-core **0.1.3** ([PR #302](https://github.com/nav-io/navio-core/pull/302)). Before 0.1.3 `subtractfeefromamount` was silently a no-op and `comment`/`comment_to` were dropped for BLSCT wallets.

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

### `stakeunlock`

Unlocks an staked amount.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `amount` | `AMOUNT` | yes | The amount in to unstake. eg 0.1 |
| 2 | `verbose` | `BOOL` | no (default `false`) | If true, return extra information about the transaction. |

**Examples**

```bash
navio-cli stakelock 0.1
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

### `listblscttransactions`

If a label name is provided, this will return only incoming transactions paying to addresses with the specified label.

Returns up to 'count' most recent transactions skipping the first 'from' transactions.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `label|dummy` | `STR` | no | If set, should be a valid label name to return only incoming transactions\n with the specified label, or \"*\" to disable filtering and return all transactions. |
| 2 | `count` | `NUM` | no (default `10`) | The number of transactions to return |
| 3 | `skip` | `NUM` | no (default `0`) | The number of transactions to skip |
| 4 | `include_watchonly` | `BOOL` | no (default `"true for watch-only wallets, otherwise false"`) | Include transactions to watch-only addresses (see 'importaddress') |

**Examples**

```bash
navio-cli listblscttransactions
```

```bash
navio-cli listblscttransactions "*" 20 100
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
navio-cli createblsctrawtransaction "[{\"txid\":\"myid\",\"value\":1000000,\"gamma\":\"1234567890abcdef\",\"spending_key\":\"abcdef1234567890\"}]" "[{\"address\":\"address\",\"amount\":1000000,\"memo\":\"memo\",\"token_id\":\"tokenid\"}]"
```

```bash
navio-cli createblsctrawtransaction "[{\"txid\":\"myid\"}]" "[{\"address\":\"address\",\"amount\":1000000}]"
```

!!! note "Atomic-swap HTLC outputs (0.1.3+)"
    An `atomic_swap` output takes `address_a` / `address_b`, `hashlock`, `locktime`, `timelock_opcode` (`"cltv"` default or `"csv"`), and an optional `blinding_key`. Since navio-core **0.1.3** ([PR #298](https://github.com/nav-io/navio-core/pull/298)), building such an output **auto-registers the HTLC script as watch-only** using `address_a`'s recovery nonce — so the wallet building the swap tracks and can recover the output (including its own timelock/refund branch) via `listblsctunspent` **without a separate [`importblsctscript`](#importblsctscript) call**. Pass a per-output `"watch_only": false` to opt out (default `true`), e.g. when building a swap on behalf of another wallet.

---

### `fundblsctrawtransaction`

Add inputs to a BLSCT transaction until it has enough value to cover outputs and fee.
If lock_unspents is true, selected inputs are locked. Use unlockblsctoutpoint to unlock them.

**Parameters**

| # | Name | Type | Required | Description |
| - | ---- | ---- | -------- | ----------- |
| 1 | `hexstring` | `STR_HEX` | yes | The hex string of the raw transaction |
| 2 | `changeaddress` | `STR` | no | The BLSCT address to receive the change |
| 3 | `lock_unspents` | `BOOL` | no (default `false`) | Lock selected unspent outputs |
| 4 | `fee` | `NUM` | no | The absolute fee in navoshis. Defaults to 1000000 |

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

<!-- generated: 35 commands -->

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

