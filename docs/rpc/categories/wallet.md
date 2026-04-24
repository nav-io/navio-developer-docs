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

## BLSCT-specific wallet commands

See the full [BLSCT commands page](../blsct.md) — especially `setblsctseed`, `getblsctseed`, `getblsctauditkey`, `dumpmnemonic`.
