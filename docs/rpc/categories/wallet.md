# Wallet RPC

!!! info "Auto-generated"
    This page is populated by the nightly documentation pipeline from `naviod -help`. Until the next build, consult `navio-cli help` on your node for the canonical list.

## Commonly used

| Command                         | Purpose                                                           |
| ------------------------------- | ----------------------------------------------------------------- |
| [`getnewaddress`](../blsct.md)                 | Generate a new BLSCT receiving address                            |
| [`getblsctbalance`](../blsct.md#getblsctbalance)              | Aggregate NAV / token / NFT balance                                |
| [`sendtoblsctaddress`](../blsct.md#sendtoblsctaddress)        | Send to a BLSCT address                                            |
| [`listblsctunspent`](../blsct.md#listblsctunspent)            | List BLSCT UTXOs                                                   |
| [`listblscttransactions`](../blsct.md#listblscttransactions)  | BLSCT-aware transaction history                                    |
| `encryptwallet`                 | Encrypt the wallet with a passphrase                              |
| `walletpassphrase`              | Unlock encrypted wallet                                           |
| `walletpassphrasechange`        | Change wallet passphrase                                          |
| `walletlock`                    | Re-lock an unlocked wallet                                        |
| `backupwallet`                  | Create a consistent on-disk backup                                |
| `restorewallet`                 | Restore wallet from backup file                                   |
| `createwallet`                  | Create a new wallet (pass `blsct=true`; mainnet requires BLSCT)   |
| `loadwallet` / `unloadwallet`   | Hot-load / unload wallet files                                    |
| `getwalletinfo`                 | Inspect current wallet status                                     |

## Creating a BLSCT wallet

`createwallet` takes several BLSCT-specific arguments:

| Argument              | Type      | Purpose                                                                                   |
| --------------------- | --------- | ----------------------------------------------------------------------------------------- |
| `blsct`               | `BOOL`    | Create a wallet with BLSCT keys (mainnet requires this).                                   |
| `seed`                | `STR_HEX` | Restore from a master seed **or** an audit key. Requires `blsct=true`.                     |
| `mnemonic`            | `STR`     | Restore from a BIP-39 mnemonic (24 words). Requires `blsct=true`. Mutually exclusive with `seed`. |
| `mnemonic_passphrase` | `STR`     | Optional BIP-39 passphrase extending the mnemonic (the "25th word"). See below.            |

### BIP-39 mnemonic passphrase {#mnemonic-passphrase}

!!! info "Requires v0.1.5+"
    `mnemonic_passphrase` shipped in navio-core **v0.1.5**. `navio-wallet create` has a matching `-mnemonicpassphrase` option. On older nodes, verify availability with `navio-cli help createwallet`.

An optional passphrase extends a BIP-39 mnemonic when deriving the wallet keys (BIP-39 seed = PBKDF2-HMAC-SHA512, 2048 iterations, salt `"mnemonic" + passphrase`):

-   The passphrase is **not stored** in the wallet. `dumpmnemonic` returns only the mnemonic — the **same passphrase must be supplied again** to restore the same wallet.
-   An **empty** passphrase keeps the legacy derive-directly-from-entropy behavior, so existing wallets and mnemonics restore unchanged.
-   Use ASCII characters to stay interoperable with other BIP-39 wallets (no NFKD normalization is applied).

```bash
# Create a BLSCT wallet whose mnemonic is extended by a passphrase.
# createwallet is positional; mnemonic_passphrase is the last argument
# (after blsct=true, storage_output, seed, mnemonic). Named form via -named:
navio-cli -named createwallet wallet_name="trading" blsct=true \
    mnemonic_passphrase="my secret passphrase"

# Or via the offline wallet tool
navio-wallet -blsct -mnemonicpassphrase="my secret passphrase" create
```

Losing the passphrase makes the funds unrecoverable even with the correct mnemonic.

## BLSCT-specific wallet commands

See the full [BLSCT commands page](../blsct.md) — especially `setblsctseed`, `getblsctseed`, `getblsctauditkey`, `dumpmnemonic`.
