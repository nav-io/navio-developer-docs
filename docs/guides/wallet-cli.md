# Wallet basics with navio-cli

Goal: create a wallet, back up its mnemonic, restore it from the mnemonic on another machine, and generate receiving addresses — using only `navio-cli` against a running `naviod`.

Verified against navio-core **v0.2.2** and current master. All commands below are BLSCT wallet commands — the default and standard wallet type on mainnet.

## Prerequisites

-   A running, synced `naviod`. Check with:

```bash
navio-cli getblockchaininfo | grep -e blocks -e headers -e verificationprogress
```

-   If you run multiple wallets, target one explicitly with `-rpcwallet=<name>` on every `navio-cli` call.

## 1. Create a wallet

```bash
navio-cli createwallet "main"
```

`createwallet` creates a BLSCT wallet by default (`blsct=true`). The response includes the wallet's mnemonic: 24 BIP-39 words followed by two [birthday words](../concepts/wallet-formats.md#birthday-mnemonic-26-words) that encode the creation time, so a later restore knows where to start scanning:

```json
{
  "name": "main",
  "mnemonic": "<word 1> <word 2> … <word 24> <birthday word 25> <birthday word 26>"
}
```

!!! danger "The mnemonic is shown only this once"
    The 26 words in the `createwallet` response are the master backup of the wallet. Write them down **now**, offline (paper or metal). They are not shown again on wallet load — though you can re-dump them later with `dumpmnemonic` while the wallet is loaded and unlocked.

To create the wallet with a [BIP-39 mnemonic passphrase](../rpc/categories/wallet.md#mnemonic-passphrase) (the "25th word", extending the seed derivation — v0.1.4+). The passphrase must be ASCII:

```bash
navio-cli -named createwallet wallet_name="main" mnemonic_passphrase="my secret passphrase"
```

To encrypt the wallet at creation, pass a passphrase:

```bash
navio-cli -named createwallet wallet_name="main" passphrase="correct horse battery staple"
```

An existing unencrypted wallet can be encrypted later with `encryptwallet`.

!!! note "Two different passphrases"
    `passphrase` encrypts the wallet file on this machine — it protects the wallet database and is not needed to restore from the mnemonic. `mnemonic_passphrase` changes the key derivation itself (what some wallets call the BIP-39 "extension words" or "25th word") — it **is** required, together with the 24 words, to restore the wallet. They are independent; you can use either or both.

## 2. Back up / dump the mnemonic

On a loaded wallet:

```bash
navio-cli dumpmnemonic
```

Returns the BIP-39 phrase, with the two birthday words appended when the wallet's creation time is known. A wallet created from a raw `seed` has no mnemonic to export; back it up with `getblsctseed`. If the wallet is encrypted, unlock it first:

```bash
navio-cli walletpassphrase "correct horse battery staple" 60   # unlock for 60 seconds
navio-cli dumpmnemonic
navio-cli walletlock
```

Related backup commands:

| Command | What it gives you |
| ------- | ----------------- |
| `dumpmnemonic` | BIP-39 mnemonic (24 words, or 26 with the birthday suffix) — the backup you want |
| `getblsctseed` | Raw 32-byte master seed as hex (lower-level equivalent) |
| `getblsctauditkey` | 80-byte watch-only audit key — balance visibility, cannot spend (see [audit wallet](audit-wallet.md)) |
| `backupwallet <path>` | Consistent copy of the wallet database (fast restore, includes history) |

!!! warning "`dumpwallet` does not back up BLSCT keys"
    The legacy `dumpwallet` command exports only transparent (ECDSA) keys and errors out on BLSCT wallets to avoid a false sense of backup. Use `dumpmnemonic` (or `getblsctseed`) plus `backupwallet` instead.

If the wallet was created with a [BIP-39 mnemonic passphrase](../rpc/categories/wallet.md#mnemonic-passphrase), the passphrase is **not stored in the wallet and not included in `dumpmnemonic` output**. Back it up separately — mnemonic + wrong passphrase restores a different (empty) wallet.

See [Node → Backup & restore](../node/backup.md) for the full backup matrix.

## 3. Restore a wallet from the mnemonic

```bash
navio-cli -named createwallet wallet_name="restored" mnemonic="abandon ability able about above absent absorb abstract absurd abuse access accident account accuse achieve acid acoustic acquire across act action actor actress actual"
```

Both the 26-word birthday mnemonic and a plain 24-word BIP-39 mnemonic are accepted. If the original wallet used a mnemonic passphrase, supply it too:

```bash
navio-cli -named createwallet wallet_name="restored" \
    mnemonic="abandon ability able ..." \
    mnemonic_passphrase="my secret passphrase"
```

Alternatively restore from the raw seed hex: `-named createwallet wallet_name="restored" seed="<64-hex-chars>"` (`seed` and `mnemonic` are mutually exclusive). Don't combine `seed` or `mnemonic` with `blank=true`, or a master seed or mnemonic with `disable_private_keys=true`. On master (after v0.2.2) `createwallet` refuses both; earlier releases created a wallet that did not match what was asked for.

### Rescan for your history

**A restored wallet does not automatically scan past blocks.** Pre-existing transactions and balance are invisible until you rescan:

```bash
navio-cli -rpcwallet=restored rescanblockchain
```

Without a start height, `rescanblockchain` starts at the wallet's birthday when it is known (a restore from the 26-word mnemonic), and otherwise at `0`, the genesis block. Pass an explicit height if you know the block when the wallet first received funds. BLSCT wallets always rescan by reading every block, even with `-blockfilterindex=1`. Then verify:

```bash
navio-cli -rpcwallet=restored getwalletinfo
navio-cli -rpcwallet=restored getblsctbalance
```

## 4. Generate a receiving address

```bash
navio-cli getnewaddress
```

Returns a new BLSCT address (BLSCT wallets default to `address_type=blsct`; no flag needed). Optionally label it:

```bash
navio-cli getnewaddress "deposits-from-exchange"
```

Every call derives a fresh sub-address from the same seed — all of them (and their funds) are recovered by the mnemonic, so generating many addresses does not complicate the backup.

## Offline: `navio-wallet`

The `navio-wallet` tool creates and inspects wallet files without a running node:

```bash
navio-wallet -wallet=offline -blsct create                          # new wallet
navio-wallet -wallet=restored -blsct -mnemonic="26 words ..." create
navio-wallet -wallet=audit -blsct -seed=<160-hex audit key> create  # watch-only
navio-wallet -wallet=offline info
```

-   `-seed` cannot be combined with `-mnemonic` or `-mnemonicpassphrase`. On master (after v0.2.2) it is checked before the wallet is created: it must be hex, 64 characters for a master seed or 160 for an audit key, and an audit key whose view-key or spend-key half is invalid is refused with "Invalid audit key". Earlier releases could create a wallet with no seed, or with a random seed whose mnemonic was never shown, from a bad value.
-   `-mnemonicpassphrase` must be ASCII for a new wallet. On restore with `-mnemonic`, a non-ASCII passphrase is accepted with a warning.
-   On master (after v0.2.2), `navio-wallet create` exits non-zero when the wallet cannot be created, for example because it already exists. Earlier releases printed the error and exited 0.
-   `navio-wallet info` on a new BLSCT wallet shows "HD (hd seed available): no" and "Keypool Size: 0": those fields describe transparent keys only.

## Quick reference

```bash
# create
navio-cli createwallet "main"                      # note the mnemonic in the response!

# backup
navio-cli dumpmnemonic                             # unlock first if encrypted

# restore
navio-cli -named createwallet wallet_name="restored" mnemonic="26 (or 24) words ..."
navio-cli -rpcwallet=restored rescanblockchain     # required to see old history

# receive
navio-cli getnewaddress
```

## Related

-   [Backup & restore](../node/backup.md) — full matrix of what each artifact recovers
-   [Wallet RPC](../rpc/categories/wallet.md) — `createwallet` arguments, mnemonic passphrase details
-   [BLSCT commands](../rpc/blsct.md) — `getblsctseed`, `getblsctauditkey`, `setblsctseed`
-   [Coin swap (Navcoin → Navio)](coin-swap.md) — if you are restoring a wallet to receive swapped coins
