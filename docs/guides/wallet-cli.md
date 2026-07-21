# Wallet basics with navio-cli

Goal: create a wallet, back up its mnemonic, restore it from the mnemonic on another machine, and generate receiving addresses — using only `navio-cli` against a running `naviod`.

Verified against navio-core **v0.1.5**. All commands below are BLSCT wallet commands — the default and standard wallet type on mainnet.

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

`createwallet` creates a BLSCT wallet by default (`blsct=true`). The response includes the wallet's BIP-39 mnemonic:

```json
{
  "name": "main",
  "mnemonic": "abandon ability able about above absent absorb abstract absurd abuse access accident account accuse achieve acid acoustic acquire across act action actor actress actual"
}
```

!!! danger "The mnemonic is shown only this once"
    The 24 words in the `createwallet` response are the master backup of the wallet. Write them down **now**, offline (paper or metal). They are not shown again on wallet load — though you can re-dump them later with `dumpmnemonic` while the wallet is loaded and unlocked.

To encrypt the wallet at creation, pass a passphrase:

```bash
navio-cli -named createwallet wallet_name="main" passphrase="correct horse battery staple"
```

An existing unencrypted wallet can be encrypted later with `encryptwallet`.

## 2. Back up / dump the mnemonic

On a loaded wallet:

```bash
navio-cli dumpmnemonic
```

Returns the 24-word BIP-39 phrase. If the wallet is encrypted, unlock it first:

```bash
navio-cli walletpassphrase "correct horse battery staple" 60   # unlock for 60 seconds
navio-cli dumpmnemonic
navio-cli walletlock
```

Related backup commands:

| Command | What it gives you |
| ------- | ----------------- |
| `dumpmnemonic` | 24-word BIP-39 mnemonic — the backup you want |
| `getblsctseed` | Raw 32-byte master seed as hex (lower-level equivalent) |
| `getblsctauditkey` | 80-byte watch-only audit key — balance visibility, cannot spend |
| `backupwallet <path>` | Consistent copy of the wallet database (fast restore, includes history) |

!!! warning "`dumpwallet` does not back up BLSCT keys"
    The legacy `dumpwallet` command exports only transparent (ECDSA) keys and errors out on BLSCT wallets to avoid a false sense of backup. Use `dumpmnemonic` (or `getblsctseed`) plus `backupwallet` instead.

If the wallet was created with a [BIP-39 mnemonic passphrase](../rpc/categories/wallet.md#mnemonic-passphrase), the passphrase is **not stored in the wallet and not included in `dumpmnemonic` output**. Back it up separately — mnemonic + wrong passphrase restores a different (empty) wallet.

See [Node → Backup & restore](../node/backup.md) for the full backup matrix.

## 3. Restore a wallet from the mnemonic

```bash
navio-cli -named createwallet wallet_name="restored" mnemonic="abandon ability able about above absent absorb abstract absurd abuse access accident account accuse achieve acid acoustic acquire across act action actor actress actual"
```

Only 24-word mnemonics are accepted. If the original wallet used a mnemonic passphrase, supply it too:

```bash
navio-cli -named createwallet wallet_name="restored" \
    mnemonic="abandon ability able ..." \
    mnemonic_passphrase="my secret passphrase"
```

Alternatively restore from the raw seed hex: `-named createwallet wallet_name="restored" seed="<64-hex-chars>"` (`seed` and `mnemonic` are mutually exclusive).

### Rescan for your history

**A restored wallet does not automatically scan past blocks.** The node treats the moment of import as the wallet's birthday, so pre-existing transactions and balance are invisible until you rescan:

```bash
navio-cli -rpcwallet=restored rescanblockchain 0
```

Use `0` to scan from genesis, or a start height if you know the block when the wallet first received funds. Then verify:

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

## Quick reference

```bash
# create
navio-cli createwallet "main"                      # note the mnemonic in the response!

# backup
navio-cli dumpmnemonic                             # unlock first if encrypted

# restore
navio-cli -named createwallet wallet_name="restored" mnemonic="24 words ..."
navio-cli -rpcwallet=restored rescanblockchain 0   # required to see old history

# receive
navio-cli getnewaddress
```

## Related

-   [Backup & restore](../node/backup.md) — full matrix of what each artifact recovers
-   [Wallet RPC](../rpc/categories/wallet.md) — `createwallet` arguments, mnemonic passphrase details
-   [BLSCT commands](../rpc/blsct.md) — `getblsctseed`, `getblsctauditkey`, `setblsctseed`
-   [Coin swap (Navcoin → Navio)](coin-swap.md) — if you are restoring a wallet to receive swapped coins
