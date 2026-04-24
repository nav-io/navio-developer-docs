# BLSCT Protocol

Deep dive into Navio's confidential transaction protocol. Start with [Concepts → BLSCT privacy model](../concepts/blsct-model.md) for the high-level picture; this section covers the cryptographic details and on-wire byte layouts.

| Page                                                              | Topic                                                                 |
| ----------------------------------------------------------------- | --------------------------------------------------------------------- |
| [BLS12-381 curve](curve.md)                                       | Pairing-friendly curve used for signatures, commitments, proofs       |
| [Key derivation](keys.md)                                         | EIP-2333, view keys, spend keys, token keys, sub-address derivation   |
| [Double public key](double-public-key.md)                         | 96-byte bundled (view, spend) public key that defines a BLSCT address |
| [Output construction](outputs.md)                                 | Ephemeral keys, commitments, view tags, blinding, memo encryption     |
| [Output detection](detection.md)                                  | How wallets scan for outputs addressed to them                        |
| [Amount recovery](amount-recovery.md)                             | Nonce-based decryption of committed amounts                           |
| [Range proofs](range-proofs.md)                                   | Bulletproofs++ layout, aggregation, verification       |
| [Signatures](signatures.md)                                       | Balance signature, input signatures, token signatures, aggregation    |
| [Proof-of-Private-Stake (PoPS)](pops.md)                          | Consensus algorithm — set-membership proof + range proof over committed stake |
| [Slashing (future work)](slashing.md)                              | Why automatic slashing is not yet live; reserved primitives for later activation |
| [Token format](tokens.md)                                         | Token / NFT outputs, collection vs. item ids, metadata encoding       |
| [Transaction format](transaction.md)                              | On-wire BLSCT transaction layout                                      |
| [Block format](block.md)                                          | BLSCT-aware block layout, coinstake, coinbase                         |
