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

On mainnet, testnet and `blsctregtest`, the transparent spend, fee and key RPCs (`sendmany`, `send`, `sendall`, `fundrawtransaction`, `signrawtransactionwithwallet`, `bumpfee`, `settxfee`, `importprivkey`, …) are refused. See [BLSCT-only networks](../index.md#blsct-only-networks) for the full list and the BLSCT alternatives.

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
| `mnemonic_passphrase`  | `STR`     | Optional BIP-39 passphrase extending the mnemonic (the "25th word"). See below.            |

A new BLSCT wallet created without `seed` or `mnemonic` returns its 26-word birthday mnemonic in the `mnemonic` field of the result.

`createwallet` rejects these combinations with `RPC_INVALID_PARAMETER` before any wallet file is created:

| Combination | Error |
| ----------- | ----- |
| `blank=true` with `seed`, `mnemonic` or `mnemonic_passphrase` | A blank wallet is created without keys, so these would be dropped |
| `disable_private_keys=true` with a master `seed` or a `mnemonic` | They hold private keys. Pass an audit key as `seed` instead |
| `disable_private_keys=true` with `mnemonic_passphrase` | The wallet derives no keys |
| `seed` with `mnemonic`, or `seed` with `mnemonic_passphrase` | Mutually exclusive |
| A 160-hex `seed` whose view-key or spend-key half is not a valid key | `Invalid audit key: the view key or the spend key is not a valid key` |

A `seed` of any length other than 64 or 160 hex characters fails with `Seed must be 64 (master) or 160 (view) characters long`.

!!! info "Changes on master (after v0.2.2)"
    -   A new BLSCT wallet no longer gets a legacy (transparent) key manager. `getwalletinfo` reports `keypoolsize` and `keypoolsize_hd_internal` as `0`, since they count transparent keys only. Existing wallet files that have a legacy key manager keep it.
    -   A watch-only BLSCT wallet (`disable_private_keys=true`) without an audit key holds **no keys**. Earlier releases generated a random seed for it, which `getblsctseed` and `dumpmnemonic` still return for wallets created that way; loading such a wallet now warns "Private keys detected in wallet … with disabled private keys".
    -   Loading a BLSCT wallet that has no seed, although it is neither blank nor watch-only, fails with "BLSCT wallet has no seed, so its creation probably did not complete" instead of stopping the node. Restore it from its mnemonic, seed or a backup.
    -   Wallets created with an external signer can no longer be loaded.

### BIP-39 mnemonic passphrase {#mnemonic-passphrase}

!!! info "Requires v0.1.4+"
    `mnemonic_passphrase` shipped in navio-core **v0.1.4**. `navio-wallet create` has a matching `-mnemonicpassphrase` option.

An optional passphrase extends a BIP-39 mnemonic when deriving the wallet keys (BIP-39 seed = PBKDF2-HMAC-SHA512, 2048 iterations, salt `"mnemonic" + passphrase`):

-   The passphrase is **not stored** in the wallet. `dumpmnemonic` returns only the mnemonic — the **same passphrase must be supplied again** to restore the same wallet.
-   An **empty** passphrase keeps the legacy derive-directly-from-entropy behavior, so existing wallets and mnemonics restore unchanged.
-   The passphrase **must be ASCII** when creating a new wallet (since v0.2.2), because no NFKD normalization is applied. When restoring with `mnemonic`, a non-ASCII passphrase is still accepted with a warning, so wallets created that way remain recoverable.

```bash
# Create a BLSCT wallet whose mnemonic is extended by a passphrase.
navio-cli -named createwallet wallet_name="trading" \
    mnemonic_passphrase="my secret passphrase"

# Or via the offline wallet tool
navio-wallet -wallet=trading -blsct -mnemonicpassphrase="my secret passphrase" create
```

Losing the passphrase makes the funds unrecoverable even with the correct mnemonic.

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

On master (after v0.2.2), `gettransaction` reports the top-level `amount` and `fee` of BLSCT transactions this wallet sent from the transaction's own fee output. Earlier releases counted the confidential payment and change as fee, which showed a large negative `fee` and a positive `amount`.

-   A send of X reports `amount` -X and `fee` equal to its BLSCT fee, matching its `details` entries and `listtransactions`.
-   A send to the wallet's own address reports `amount` 0.
-   A transaction in which this wallet's coins only served as aggregation cover, and all came back as change, reports `fee` 0.
-   A merged block transaction (a staker combined several senders' transactions into one) that the wallet learned of only by rescanning reports the merged fee of every sender, as its `details` entries do.
-   Ordinary sends of an output-storage wallet are no longer flagged `involvesWatchonly: true` in `listtransactions`, `listsinceblock` and `gettransaction`.

A wallet restored from a seed after a staker merged a chain of its sends into one block transaction shows one `send` row for that block transaction, now with the amount paid to others and the merged fee.

The `outputHash` returned by the BLSCT sending RPCs is not a txid. Look the transaction up with [`gettxfromoutputhash`](rawtransactions.md#output-hash-lookups) first.

## Other wallet behaviour

-   **`keypoolrefill`** on a BLSCT wallet refills the BLSCT sub-address pool (`blsct=true`, the default). With `blsct=false` a new BLSCT wallet has no transparent pool, so a size above 0 fails with "Error refreshing keypool."
-   **`consolidate`** with `max_txs` above 1 stops at the first failure after something was sent and returns the txids already broadcast (the failure goes to the wallet log). A short result no longer always means the wallet ran out of outputs. `max_inputs` must not be negative.
-   **Rescans** of BLSCT wallets always read every block, even with `-blockfilterindex=1` (block filters cannot match outputs found by view key). If you ran a BLSCT wallet created with `navio-wallet create` on a node with `-blockfilterindex=1`, run `rescanblockchain` once after upgrading.
-   **Chained sends after an aggregated send.** On master, the wallet records its own aggregated `sendtoblsctaddress`, `consolidate`, `aggregatesend` or `acceptquotewallet` broadcast immediately and treats its own change as trusted at 0 confirmations, so a follow-up send no longer fails with "Not enough funds available". Outputs funded only by other parties' inputs (a cover candidate addressed to you, or the token you receive in a swap) stay untrusted until the transaction confirms.
-   **Conflicted or expired sends.** On an output-storage wallet, an aggregated send whose cover input is double-spent in a block is marked conflicted (`confirmations` goes negative) and its inputs return to the balance without `abandontransaction`. A send that leaves the mempool without a conflict stops counting as trusted, and `abandontransaction` now accepts it.
-   **`fundrawtransaction` `input_weights`** (transparent wallets, non-BLSCT networks only): each entry takes `outid` and `weight`. The minimum accepted weight is 149, the weight of an empty Navio input.

## BLSCT-specific wallet commands

See the full [BLSCT commands page](../blsct.md) — especially `setblsctseed`, `getblsctseed`, `getblsctauditkey`, `dumpmnemonic`, `listwallettokens` and `signblsctoutput`.
