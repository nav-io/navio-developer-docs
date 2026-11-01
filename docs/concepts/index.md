# Concepts

The protocol from the top down. Read this section if you want to understand *why* Navio transactions look the way they do before you integrate with the node, SDK, or explorer.

| Page                                                  | What's covered                                                                                                     |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| [Navio overview](overview.md)                         | Fork genealogy, design goals, what's the same as Bitcoin Core and what's different.                                |
| [BLSCT privacy model](blsct-model.md)                 | BLS12-381, Pedersen commitments, double public keys, view tags, stealth addresses.                                 |
| [Outpoint model](outpoint.md)                         | Why Navio identifies each output by a single `output_hash` instead of `txid:vout`, and what that means for tooling. |
| [Consensus & supply](consensus.md)                    | Mainnet PoPS, testnet PoS/BLSCT, genesis supply, fee burn, staking, block cadence.                                 |
| [Networks](networks.md)                               | Mainnet, testnet, signet, regtest. Ports, magic bytes, bech32 HRPs, bootstrap nodes.                               |
| [P2P protocol](p2p-protocol.md)                       | Service bits, transports, output-hash relay, aggregated blocks, compact blocks v3, light-wallet `outkeys`, WebSocket. |
| [P2P encrypted messaging](p2p-messaging.md)           | The encrypted broadcast overlay: envelopes, detection, archive, user messaging, cover traffic.                     |
| [Wallet formats](wallet-formats.md)                   | HD chain, sub-address accounts, BIP-39 mnemonic, audit keys, seed backup.                                          |
| [Atomic swaps](atomic-swaps.md)                       | Cross-chain and intra-chain swap mechanics.                                                                        |
