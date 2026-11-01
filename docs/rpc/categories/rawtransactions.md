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
| `gettxfromoutputhash`                                            | Find the transaction that created an output        |
| `getoutputinfo`                                                  | Where an output was created and spent (needs `-outindex`) |

`createblsctrawtransaction` outputs take a `token_id`: the 64-hex token id, the token id followed by `#<subid>` for an NFT (on master, after v0.2.2), or empty for NAV. A malformed `token_id` fails with `RPC_INVALID_PARAMETER`.

On mainnet, testnet and `blsctregtest`, `createrawtransaction`, `signrawtransactionwithkey`, `fundrawtransaction` and `signrawtransactionwithwallet` are refused. See [BLSCT-only networks](../index.md#blsct-only-networks).

!!! warning "PSBT is not supported"
    Navio does not implement BIP-174 PSBT. On master (after v0.2.2) every PSBT RPC has been removed (`createpsbt`, `decodepsbt`, `analyzepsbt`, `walletcreatefundedpsbt`, `walletprocesspsbt`, …) and calling one fails with `Method not found`. Use the BLSCT raw-transaction flow above; the end-to-end is covered in the [raw BLSCT tx guide](../../guides/raw-blsct-tx.md).

## Output-hash lookups {#output-hash-lookups}

Navio identifies outputs by their output hash, not `txid:vout` (see [outpoint model](../../concepts/outpoint.md)). The BLSCT sending, minting and staking RPCs return an `outputHash`, which is **not a txid**. To find its transaction:

```bash
navio-cli gettxfromoutputhash "<outputhash>"
# { "txid": "...", "vout": 0, "blockhash": "...", "confirmations": 3 }
```

| Argument | Default | Meaning |
| -------- | ------- | ------- |
| `outputhash` | — | The output hash to look up |
| `include_mempool` | `true` | Also search mempool transactions |

`blockhash` and `confirmations` are present only once the transaction is confirmed. Without `-outindex`, an unspent output is answered from the UTXO set, and an output already spent in a block is found by scanning the chain backwards from the tip, which is slow; on a pruned node that scan fails once it reaches pruned blocks.

### `-outindex` and `getoutputinfo`

On master (after v0.2.2), the optional `-outindex` index (default off, incompatible with pruning) maps each output hash to the block, transaction and output position that created it and, once spent, to the spending position. It is built in the background and reported by `getindexinfo` as `outindex`. With it enabled and synced, `gettxfromoutputhash` answers confirmed outputs, spent or not, from the index.

```bash
navio-cli getoutputinfo "<outputhash>"
```

Returns `txid`, `vout`, `blockhash`, `height`, `confirmations`, `spent`, and when spent a `spentby` object with `txid`, `vin`, `blockhash` and `height`. Only the active chain is consulted; outputs created or spent only in the mempool are not reported.
