# Offline cold signing (air-gapped)

Goal: keep the spending key on a device that **never touches the internet**, while a watch-only wallet on your everyday phone or computer tracks balances and prepares transactions. The two devices talk exclusively through QR codes shown on one screen and scanned by the other camera - no cable, no Bluetooth, no radio.

Available in **Navio Electrum v4.9.3+** on Android and desktop. An ordinary spare phone or laptop becomes a hardware-wallet-grade signer.

## How it fits together

BLSCT wallets split cleanly into a view half and a spend half (see [Watch-only audit wallet](audit-wallet.md) for the key format). Air-gapped signing builds on that split:

| Device | Wallet | Holds | Can |
| ------ | ------ | ----- | --- |
| Online (everyday phone/PC) | watch-only | view key | scan the chain, see balances and history, compose transaction proposals, broadcast signed transactions |
| Offline (spare phone/laptop, airplane mode forever) | full | seed / spend key | verify proposals independently, sign |

A payment then flows:

1. The **online wallet** composes a *transaction proposal* - which outputs to spend, where to send, fee - and displays it as a looping sequence of QR codes.
2. The **offline wallet** scans it, independently rebuilds the transaction, and shows you every output and the fee for review. It refuses proposals for a different network or a different wallet.
3. You press **Sign**. The offline wallet builds and signs the complete transaction and answers with another QR sequence.
4. The online wallet scans the reply and broadcasts.

## Trust model

The design assumes the online device may be fully compromised:

- **The signer verifies everything itself.** The offline wallet does not trust any amount, address, or fee claimed by the proposal - it re-derives the transaction from its own keys and shows you what will actually be signed.
- **Change never appears in proposals.** The signer derives the change address from its own seed, so a compromised online device cannot redirect change to an attacker.
- **Proposals are bound to one network and one wallet.** The envelope carries the genesis block hash and a fingerprint of the view key; anything else is rejected before parsing.
- **Malformed input is rejected structurally.** Field types, list sizes, and bounds on accounts, address indexes, and amounts are all validated on the signer, so hostile payloads cannot crash it or exhaust its keypool.
- A proposal older than a day triggers a warning on the signer.

What an attacker who owns your online device *can* still do: see your balances and history (it holds the view key), and propose transactions - which then appear on the offline screen for you to reject. Reading the signer screen carefully before pressing Sign is the one habit the scheme asks of you.

## Setup

You need two devices with cameras and [Navio Electrum](https://github.com/nav-io/navio-electrum/releases/latest) v4.9.3 or later.

### 1. Offline device: create the full wallet

On the spare phone or laptop, enable airplane mode (and keep it that way), then create a standard Navio wallet. Write the seed down on paper as usual - the device can die; the seed is the backup.

### 2. Export the view key

On the offline wallet: **Wallet menu → View key** (desktop: `Wallet → Information`). It is shown as a QR code and as 160 hex characters - `view_secret (32 bytes) || master_spend_pubkey (48 bytes)`, the same audit-key format Navio Core's `createwallet` accepts.

### 3. Online device: create the watch-only wallet

On your everyday device: create a new wallet, choose **Restore**, and scan the view-key QR (or paste the hex). The wallet syncs the full history and balance but holds no signing material.

## Daily use

### Send

On the watch-only wallet, make a payment as normal. Instead of a confirmation dialog you get the looping proposal QR:

1. Offline device: **Wallet menu → Air-gapped signer → Scan proposal**, point it at the online screen. It shows *Received n of m parts* until complete.
2. Review the outputs and the fee on the offline screen, press **Sign**.
3. Online device: **Scan signed transaction**, point it at the offline screen. It broadcasts automatically.

### Stake, unstake, delegate

The watch-only wallet's Staking page works the same way: stake, unstake, and [cold-staking delegations](../node/cold-staking.md) all become proposals for the offline signer. Combined with cold staking this gives the strongest available setup: the delegation key is the only hot material anywhere, the spend key lives on the air-gapped device, and the everyday device holds only the view key.

### Tokens and NFTs

Token and NFT sends from the watch-only wallet follow the same propose → sign → broadcast loop.

## Wire format

For implementers - the QR payload format (also documented in `electrum/airgap.py`):

- The payload is a canonical-CBOR map, zlib-compressed, base64url-encoded, and split into fragments of 280 characters.
- Each QR frame is one fragment: `NAV-AG/<version>/<msgid>/<i>/<n>/<data>`, where `msgid` is the first 8 hex chars of the SHA-256 of the compressed payload - fragments of different messages never mix.
- Fragments can be scanned in any order; the display loops at ~2.5 frames per second until the scanner has the full set.
- The envelope carries `{v, t, net, fp, ts}`: version, type (`prop`/`signed`), genesis hash, view-key fingerprint, and timestamp.
- Proposals list inputs by output hash and outputs as `(address, amount, memo, type, ...)`. Change is intentionally absent - the signer derives it.

## Troubleshooting

- **Scanner never completes:** hold the phone steady 10-20 cm from the screen and raise the screen brightness. All fragments must be captured; the counter shows progress.
- **"This payload belongs to a different wallet":** the watch-only wallet was restored from a different view key than the signer's. Re-export the view key from the signing wallet.
- **"This proposal is for a different network":** one device is on testnet and the other on mainnet.
- Versions older than 4.9.3 could not reliably scan between real devices - update both sides.
