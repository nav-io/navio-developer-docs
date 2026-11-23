# Wallet RPC

!!! info "Auto-generated"
    This page is populated by the nightly documentation pipeline from `naviod -help`. Until the next build, consult `navio-cli help` on your node for the canonical list.

## Commonly used

| Command                         | Purpose                                                           |
| ------------------------------- | ----------------------------------------------------------------- |
| `getnewaddress`                 | Generate a new BLSCT receiving address (BLSCT wallets default to `address_type=blsct`) |
| [`getblsctbalance`](../blsct.md#getblsctbalance)              | Aggregate NAV / token / NFT balance                                |
| [`sendtoblsctaddress`](../blsct.md#sendtoblsctaddress)        | Send to a BLSCT address                                            |
| [`listblsctunspent`](../blsct.md#listblsctunspent)            | List BLSCT UTXOs                                                   |
| [`consolidate`](../blsct.md#consolidate)                      | Merge many small outputs into fewer large ones                     |
| `listtransactions` / `listsinceblock` / `gettransaction` | Transaction history, BLSCT-aware (see [below](#gettransaction-on-blsct-wallets)) |
| `encryptwallet`                 | Encrypt the wallet with a passphrase                              |
| `walletpassphrase`              | Unlock encrypted wallet                                           |
| `walletpassphrasechange`        | Change wallet passphrase                                          |
| `walletlock`                    | Re-lock an unlocked wallet                                        |
| `backupwallet`                  | Create a consistent on-disk backup                                |
| `restorewallet`                 | Restore wallet from backup file                                   |
| `createwallet`                  | Create a new wallet (BLSCT by default)                            |
| `loadwallet` / `unloadwallet`   | Hot-load / unload wallet files                                    |
| `getwalletinfo`                 | Inspect current wallet status                                     |

On mainnet, testnet, `blsctregtest` and (from v0.3.0) signet, the transparent spend, fee and key RPCs (`sendmany`, `send`, `sendall`, `fundrawtransaction`, `signrawtransactionwithwallet`, `bumpfee`, `settxfee`, `importprivkey`, …) are refused. See [BLSCT-only networks](../index.md#blsct-only-networks) for the full list and the BLSCT alternatives.

## Creating a BLSCT wallet

`createwallet` creates a BLSCT wallet unless you pass `blsct=false`. The BLSCT-relevant arguments:

| Argument               | Type      | Purpose                                                                                   |
| ---------------------- | --------- | ----------------------------------------------------------------------------------------- |
| `disable_private_keys` | `BOOL`    | Watch-only. For a BLSCT wallet only an audit key may be passed as `seed`; without one the wallet holds no keys. |
| `blank`                | `BOOL`    | Create without keys or seed. Set one later with `setblsctseed`.                            |
| `external_signer`      | `BOOL`    | No longer supported. Kept for positional compatibility; `true` is an error.               |
| `blsct`                | `BOOL`    | Default `true`. Setting both `blsct` and `descriptors` to `true` explicitly is an error.  |
| `storage_output`       | `BOOL`    | Store outputs instead of full transactions. Default `true` for BLSCT wallets.             |
| `seed`                 | `STR_HEX` | Restore from a master seed (64 hex) **or** create a watch-only wallet from an audit key (160 hex). Requires `blsct=true`. |
| `mnemonic`             | `STR`     | Restore from a BIP-39 mnemonic: 24 words, or 26 with the Navio [birthday suffix](../../concepts/wallet-formats.md#birthday-mnemonic-26-words). Mutually exclusive with `seed`. |
| `seedphrase_extension` | `STR`     | Optional seedphrase extension (BIP-39 passphrase, the "25th word") extending the mnemonic. Named `mnemonic_passphrase` before v0.3.0. See below. |

A new BLSCT wallet created without `seed` or `mnemonic` returns its 26-word birthday mnemonic in the `mnemonic` field of the result.

`createwallet` rejects these combinations with `RPC_INVALID_PARAMETER` before any wallet file is created:

| Combination | Error |
| ----------- | ----- |
| `blank=true` with `seed`, `mnemonic` or `seedphrase_extension` | A blank wallet is created without keys, so these would be dropped |
| `disable_private_keys=true` with a master `seed` or a `mnemonic` | They hold private keys. Pass an audit key as `seed` instead |
| `disable_private_keys=true` with `seedphrase_extension` | The wallet derives no keys |
| `seed` with `mnemonic`, or `seed` with `seedphrase_extension` | Mutually exclusive |
| `seedphrase_extension` together with its alias `mnemonic_passphrase` | `Parameter seedphrase_extension specified multiple times (also as its alias mnemonic_passphrase)` |
| A 160-hex `seed` whose view-key or spend-key half is not a valid key | `Invalid audit key: the view key or the spend key is not a valid key` |

A `seed` of any length other than 64 or 160 hex characters fails with `Seed must be 64 (master) or 160 (view) characters long`.

!!! info "New in v0.3.0"
    -   A new BLSCT wallet no longer gets a legacy (transparent) key manager. `getwalletinfo` reports `keypoolsize` and `keypoolsize_hd_internal` as `0`, since they count transparent keys only. Existing wallet files that have a legacy key manager keep it.
    -   A watch-only BLSCT wallet (`disable_private_keys=true`) without an audit key holds **no keys**. Earlier releases generated a random seed for it, which `getblsctseed` and `dumpmnemonic` still return for wallets created that way; loading such a wallet now warns "Private keys detected in wallet … with disabled private keys".
    -   Loading a BLSCT wallet that has no seed, although it is neither blank nor watch-only, fails with "BLSCT wallet has no seed, so its creation probably did not complete" instead of stopping the node. Restore it from its mnemonic, seed or a backup.
    -   Wallets created with an external signer can no longer be loaded.
    -   When `createwallet` fails after it created the wallet's database (for example because the BLSCT keys cannot be set up from the given seed), it removes the wallet file and every directory level it created, so a retry with the same name no longer fails with "Database already exists". Files and directories that existed before the call are left alone. A failed `restorewallet` does the same. While `createwallet` or `restorewallet` runs, `loadwallet`, `createwallet` and `restorewallet` of the same name fail with "Wallet already loading.".

### Seedphrase extension (BIP-39 passphrase) {#seedphrase-extension}

!!! info "Renamed in v0.3.0"
    The argument shipped in navio-core **v0.1.4** as `mnemonic_passphrase`, with the `navio-wallet create` option `-mnemonicpassphrase`. From **v0.3.0** they are `seedphrase_extension` and `-seedphraseextension`. The old names still work as deprecated aliases (`-mnemonicpassphrase` prints a warning) and will be removed in a later release; passing both names is an error. `-noseedphraseextension` and `-nomnemonicpassphrase` are refused (v0.2.2 accepted `-nomnemonicpassphrase` and derived the wallet with the extension `0`). The rename does not change key derivation: the same mnemonic and extension derive the same keys under either name.

An optional seedphrase extension extends a BIP-39 mnemonic when deriving the wallet keys (BIP-39 seed = PBKDF2-HMAC-SHA512, 2048 iterations, salt `"mnemonic" + extension`). It is unrelated to the wallet encryption `passphrase`.

-   The extension is **not stored** in the wallet. `dumpmnemonic` returns only the mnemonic — the **same extension must be supplied again** to restore the same wallet.
-   An **empty** extension keeps the legacy derive-directly-from-entropy behavior, so existing wallets and mnemonics restore unchanged.
-   The extension **must be ASCII** when creating a new wallet (since v0.2.2), because no NFKD normalization is applied. When restoring with `mnemonic`, a non-ASCII extension is still accepted with a warning, so wallets created that way remain recoverable.

```bash
# Create a BLSCT wallet whose mnemonic is extended (v0.3.0 names).
navio-cli -named createwallet wallet_name="trading" \
    seedphrase_extension="my secret extension"

# Or via the offline wallet tool
navio-wallet -wallet=trading -blsct -seedphraseextension="my secret extension" create
```

On v0.2.2 and earlier use `mnemonic_passphrase=` and `-mnemonicpassphrase=`.

Losing the extension makes the funds unrecoverable even with the correct mnemonic.

## Watch-only (audit-key) wallets

Pass the 160-hex audit key from [`getblsctauditkey`](../blsct.md#getblsctauditkey) as `seed`. `disable_private_keys` is set automatically:

```bash
navio-cli -named createwallet wallet_name="audit" seed="<160-hex audit key>"
```

On a wallet without private keys:

| Call | Result |
| ---- | ------ |
| `getblsctseed` | `RPC_WALLET_BLANK` (-37), "Wallet has no BLSCT seed (private keys are disabled)" |
| `dumpmnemonic` | `RPC_WALLET_ERROR` (-4), same message |
| `getblsctauditkey` on a keyless wallet (blank, or private keys disabled without an audit key) | `RPC_WALLET_BLANK` (-37) with a message naming the cause. Earlier releases returned a generic `-1` error |
| `keypoolrefill` | "Error: Private keys are disabled for this wallet" |
| `signblsctrawtransaction` | Refused: the wallet holds no spend key |
| `createwallet` with a `passphrase` | Refused: there are no private keys to encrypt |

See [Build a watch-only audit wallet](../../guides/audit-wallet.md).

## `gettransaction` on BLSCT wallets {#gettransaction-on-blsct-wallets}

From v0.3.0, `gettransaction` reports the top-level `amount` and `fee` of BLSCT transactions this wallet sent from the transaction's own fee output. Earlier releases counted the confidential payment and change as fee, which showed a large negative `fee` and a positive `amount`.

-   A send of X reports `amount` -X and `fee` equal to its BLSCT fee, matching its `details` entries and `listtransactions`.
-   A send to the wallet's own address reports `amount` 0.
-   A transaction in which this wallet's coins only served as aggregation cover, and all came back as change, reports `fee` 0.
-   A merged block transaction (a staker combined several senders' transactions into one) that the wallet learned of only by rescanning reports the merged fee of every sender, as its `details` entries do. Such a send, and the transaction, carry `"fee_may_include_other_senders": true` in `gettransaction`, `listtransactions`, `listsinceblock` and `listpendingtransactions`: its `fee` may include fees other wallets paid, and its `amount` leaves them out, so their sum is still what the wallet spent. The field is absent for every other transaction, including a block transaction whose inputs are all the wallet's own.
-   A wallet that keeps full transactions (`storage_output=false`) reports **its own fee** for a block transaction that replaced its merged sends: the fees of the replaced sends and the amount they paid to others, instead of the whole block fee. The sum of `amount` and `fee`, and the balances, are unchanged. The own fee is stored in the transaction's metadata as `ownfee`; an older version that loads the wallet shows it as an extra `ownfee` field and reports the whole block fee.
-   A swap taken with `acceptquotewallet` reports a `fee` of 0 and an `amount` of the full sell cost, since the maker's half funds the whole fee. Swaps recorded before the upgrade keep their old figures.
-   On a full-transaction wallet an NFT input is no longer debited as NAV, so an NFT send reports `amount` 0 (plus its fee).
-   Ordinary sends of an output-storage wallet are no longer flagged `involvesWatchonly: true` in `listtransactions`, `listsinceblock` and `gettransaction`.

A wallet restored from a seed after a staker merged a chain of its sends into one block transaction shows one `send` row for that block transaction, now with the amount paid to others and the merged fee.

### Output-storage entries {#output-storage-entries}

In v0.3.0, `listtransactions`, `listsinceblock` and `listpendingtransactions` no longer report a `txid` for entries an output-storage wallet holds as a bare output, without the transaction that created it (`"output_storage": true`: payments received from others, staking rewards). Those entries used to repeat their `outid` under `txid`, which is not a transaction id. `outid` still names the output; `gettxfromoutputhash` (or `getoutputinfo` with `-outindex`) finds the transaction, and `gettransaction` still accepts the `outid`, returning it in its required top-level `txid` field. Rows in `listsinceblock`'s `removed` array still carry the real `txid` of the detached transaction.

`listunspent` on an output-storage wallet lists each coin once, with its address and recovered amount (v0.2.2 listed the change of the wallet's own sends twice), skips the outputs of a transaction that is neither confirmed nor in the mempool, even with `include_unsafe`, and applies `maximumCount` and `minimumSumAmount` after the `addresses` filter, across transparent and BLSCT coins together.

The `outputHash` returned by the BLSCT sending RPCs is not a txid. Look the transaction up with [`gettxfromoutputhash`](rawtransactions.md#output-hash-lookups) first.

## Other wallet behaviour

-   **`keypoolrefill`** on a BLSCT wallet refills the BLSCT sub-address pool (`blsct=true`, the default). With `blsct=false` a new BLSCT wallet has no transparent pool, so a size above 0 fails with "Error refreshing keypool."
-   **`consolidate`** with `max_txs` above 1 stops at the first failure after something was sent and returns the txids already broadcast (the failure goes to the wallet log). A short result no longer always means the wallet ran out of outputs. `max_inputs` must not be negative.
-   **Rescans** of BLSCT wallets always read every block, even with `-blockfilterindex=1` (block filters cannot match outputs found by view key). If you ran a BLSCT wallet created with `navio-wallet create` on a node with `-blockfilterindex=1`, run `rescanblockchain` once after upgrading.
-   **Chained sends after an aggregated send.** From v0.3.0, the wallet records its own aggregated `sendtoblsctaddress`, `consolidate`, `aggregatesend` or `acceptquotewallet` broadcast immediately and treats its own change as trusted at 0 confirmations, so a follow-up send no longer fails with "Not enough funds available". Outputs funded only by other parties' inputs (a cover candidate addressed to you, or the token you receive in a swap) stay untrusted until the transaction confirms.
-   **Conflicted or expired sends.** On an output-storage wallet, an aggregated send whose cover input is double-spent in a block is marked conflicted (`confirmations` goes negative) and its inputs return to the balance without `abandontransaction`. A send that leaves the mempool without a conflict stops counting as trusted, and `abandontransaction` now accepts it.
-   **Sends merged into a mempool transaction** (new in v0.3.0, output-storage wallets). While a transaction that merges the wallet's send (spends all its inputs and creates all its non-fee outputs) is in the mempool under its own hash, typically a block transaction returned to the mempool when its block was disconnected, the send counts as in the mempool: its change is trusted and listed, `abandontransaction` refuses it, and the wallet does not rebroadcast it. When the merging transaction leaves the mempool unmined, the send can be abandoned again.
-   **Conflicted receives** (new in v0.3.0, output-storage wallets). A received payment evicted from the mempool because a block spends one of its inputs (or an input of a payment it descends from) leaves `listtransactions` and appears in `listpendingtransactions` as a `receive` with negative `confirmations`, `trusted` false and its `outid` as `txid`. A send of this wallet that spends it is marked conflicted with the same block. If that block is disconnected, both become unconfirmed again. A payment the node did not have in its mempool when the block arrived stays unconfirmed as before, and `abandontransaction` still does not accept a received payment.
-   **Mints and token conflicts** (new in v0.3.0). `minttoken` and `mintnft` spend native coins only, for the fee; they no longer move the issuer's existing coins of the minted token through the mint. A wallet transaction the mempool evicts because its token predicate no longer holds at the new tip (for example a mint whose supply cap a block reached) is marked conflicted with that block (`confirmations` -1), so its coins come back without `abandontransaction`. A wallet that missed the eviction leaves the transaction unconfirmed with its inputs spent; use `abandontransaction`.
-   **`removeprunedfunds`** (new in v0.3.0) fully forgets a send in an output-storage wallet: its change is no longer counted or listed and the coin it spent is unspent again. A send a staker merged into a block transaction under another hash is the exception.
-   **`simulaterawtransaction`** (new in v0.3.0) reports the correct `balance_change` for BLSCT transactions: outputs are credited with the amount the wallet recovers, staked commitments count as the wallet's own, and only NAV outputs count. An out-of-range transparent output value is an error.
-   **`fundrawtransaction` `input_weights`** (transparent wallets, non-BLSCT networks only): each entry takes `outid` and `weight`. The minimum accepted weight is 149, the weight of an empty Navio input.

## BLSCT-specific wallet commands

See the full [BLSCT commands page](../blsct.md) — especially `setblsctseed`, `getblsctseed`, `getblsctauditkey`, `dumpmnemonic`, `listwallettokens` and `signblsctoutput`.
