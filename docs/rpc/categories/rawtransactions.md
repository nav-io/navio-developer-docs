# Raw transaction RPC

Mainnet is BLSCT-only. Use the BLSCT raw-transaction commands — they are the only way to work with mainnet outputs at the raw level.

| Command                                                          | Purpose                                           |
| ---------------------------------------------------------------- | ------------------------------------------------- |
| [`createblsctrawtransaction`](../blsct.md#createblsctrawtransaction) | Build unsigned BLSCT tx hex from inputs and outputs |
| [`fundblsctrawtransaction`](../blsct.md#fundblsctrawtransaction)     | Add inputs to reach target value; computes change   |
| [`signblsctrawtransaction`](../blsct.md#signblsctrawtransaction)     | Sign with wallet keys                               |
| [`decodeblsctrawtransaction`](../blsct.md#decodeblsctrawtransaction) | Decode hex to JSON without sending                  |
| [`unlockblsctoutpoint`](../blsct.md#unlockblsctoutpoint)             | Release an outpoint locked by the wallet            |
| `sendrawtransaction`                                             | Broadcast a signed raw tx (generic; works on BLSCT) |
| `getrawtransaction`                                              | Fetch a tx from chain or mempool (generic)          |

!!! warning "PSBT is not supported"
    Navio does not implement BIP-174 PSBT (yet). Use the BLSCT raw-transaction flow above; the equivalent end-to-end is covered in the [raw BLSCT tx guide](../../guides/raw-blsct-tx.md).
