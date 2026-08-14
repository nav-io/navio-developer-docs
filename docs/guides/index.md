# Guides

End-to-end tutorials. Each guide is task-shaped — you start empty, follow the steps, and end with a working artefact.

| Guide                                                      | You build                                                              |
| ---------------------------------------------------------- | ---------------------------------------------------------------------- |
| [Wallet basics with navio-cli](wallet-cli.md)              | Create, back up, restore, and receive — pure `navio-cli`               |
| [Build a wallet with navio-sdk](sdk-wallet.md)             | Node.js wallet CLI: create, sync, send                                 |
| [Mint an NFT collection](mint-nft.md)                       | Token collection + NFTs + transfer, from scratch                       |
| [Build a watch-only audit wallet](audit-wallet.md)         | Exchange-style deposit monitor driven by audit key                     |
| [Offline cold signing (air-gapped)](airgap-signing.md)     | Sign with Navio Electrum on an offline device over QR codes            |
| [Best-practice secure setup](secure-setup.md)              | Cold staking node + air-gapped signer + watch wallet, end to end       |
| [Run a staking node on a VPS](staking-vps.md)              | Hardened naviod + navio-staker under runit (non-systemd)                |
| [Atomic swaps walkthrough](atomic-swaps.md)                | Cross-chain BTC↔NAV HTLC swap + intra-chain NAV↔TOKEN swap             |
| [Self-host full stack](self-host-stack.md)                 | naviod + ElectrumX + navio-blocks explorer, docker-compose              |
| [Exchange integration](exchange-integration.md)            | Deposit detection, cold-storage pattern, withdrawal signer              |
| [Build and broadcast a raw BLSCT tx](raw-blsct-tx.md)       | Hand-rolled `createblsctrawtransaction` → fund → sign → broadcast       |
