# Error codes

## JSON-RPC standard

Per [JSON-RPC 2.0 spec](https://www.jsonrpc.org/specification#error_object):

| Code          | Name                   | Meaning                                 |
| ------------- | ---------------------- | --------------------------------------- |
| `-32700`      | `RPC_PARSE_ERROR`      | Parse error (invalid JSON)              |
| `-32600`      | `RPC_INVALID_REQUEST`  | Invalid Request                         |
| `-32601`      | `RPC_METHOD_NOT_FOUND` | Method not found, including RPCs that have been removed |
| `-32602`      | `RPC_INVALID_PARAMS`   | Invalid params                          |
| `-32603`      | `RPC_INTERNAL_ERROR`   | Internal error                          |

## navio-core (Bitcoin-derived)

Source: [`src/rpc/protocol.h`](https://github.com/nav-io/navio-core/blob/master/src/rpc/protocol.h) in navio-core.

### General

| Code   | Name                          | When                                                              |
| ------ | ----------------------------- | ----------------------------------------------------------------- |
| `-1`   | `RPC_MISC_ERROR`              | Miscellaneous; also the transparent generate / raw-tx RPCs refused on BLSCT-only networks |
| `-3`   | `RPC_TYPE_ERROR`              | Unexpected type was passed as a parameter                         |
| `-5`   | `RPC_INVALID_ADDRESS_OR_KEY`  | Bad address or key; also multisig with a `blsct` / `blsct-stake` address type |
| `-7`   | `RPC_OUT_OF_MEMORY`           | Ran out of memory during the operation                            |
| `-8`   | `RPC_INVALID_PARAMETER`       | Invalid, missing or duplicate parameter (e.g. a malformed token id, an invalid audit key, a refused `createwallet` combination) |
| `-20`  | `RPC_DATABASE_ERROR`          | Database error                                                    |
| `-22`  | `RPC_DESERIALIZATION_ERROR`   | Raw transaction or block failed to parse                          |
| `-25`  | `RPC_VERIFY_ERROR`            | General error during transaction or block submission              |
| `-26`  | `RPC_VERIFY_REJECTED`         | Transaction or block rejected by network rules                    |
| `-27`  | `RPC_VERIFY_ALREADY_IN_CHAIN` | Transaction already in chain                                      |
| `-28`  | `RPC_IN_WARMUP`               | Node still warming up                                             |
| `-32`  | `RPC_METHOD_DEPRECATED`       | RPC method is deprecated                                          |

### P2P client

| Code   | Name                               | When                                              |
| ------ | ---------------------------------- | ------------------------------------------------- |
| `-9`   | `RPC_CLIENT_NOT_CONNECTED`         | Node is not connected to the network             |
| `-10`  | `RPC_CLIENT_IN_INITIAL_DOWNLOAD`   | Still downloading initial blocks                  |
| `-23`  | `RPC_CLIENT_NODE_ALREADY_ADDED`    | Node is already added                             |
| `-24`  | `RPC_CLIENT_NODE_NOT_ADDED`        | Node has not been added before                    |
| `-29`  | `RPC_CLIENT_NODE_NOT_CONNECTED`    | Node to disconnect not found                      |
| `-30`  | `RPC_CLIENT_INVALID_IP_OR_SUBNET`  | Invalid IP / subnet                               |
| `-31`  | `RPC_CLIENT_P2P_DISABLED`          | No connection manager (networking disabled)       |
| `-33`  | `RPC_CLIENT_MEMPOOL_DISABLED`      | No mempool instance                               |
| `-34`  | `RPC_CLIENT_NODE_CAPACITY_REACHED` | Max outbound or block-relay connections already open |

### Wallet

| Code  | Name                                    | When                                              |
| ----- | --------------------------------------- | ------------------------------------------------- |
| `-4`  | `RPC_WALLET_ERROR`                      | Generic wallet failure; also wallet RPCs refused on BLSCT-only networks or on BLSCT wallets |
| `-6`  | `RPC_WALLET_INSUFFICIENT_FUNDS`         | Not enough funds                                  |
| `-11` | `RPC_WALLET_INVALID_LABEL_NAME`         | Invalid label name                                |
| `-12` | `RPC_WALLET_KEYPOOL_RAN_OUT`            | Keypool ran out; call `keypoolrefill`             |
| `-13` | `RPC_WALLET_UNLOCK_NEEDED`              | Call `walletpassphrase` first                     |
| `-14` | `RPC_WALLET_PASSPHRASE_INCORRECT`       | Wrong wallet passphrase                           |
| `-15` | `RPC_WALLET_WRONG_ENC_STATE`            | Encrypted vs unencrypted mismatch                 |
| `-16` | `RPC_WALLET_ENCRYPTION_FAILED`          | Failed to encrypt the wallet                      |
| `-17` | `RPC_WALLET_ALREADY_UNLOCKED`           | Wallet is already unlocked                        |
| `-18` | `RPC_WALLET_NOT_FOUND`                  | Invalid wallet specified                          |
| `-19` | `RPC_WALLET_NOT_SPECIFIED`              | Several wallets loaded and none specified (use `-rpcwallet`) |
| `-35` | `RPC_WALLET_ALREADY_LOADED`             | This wallet is already loaded                     |
| `-36` | `RPC_WALLET_ALREADY_EXISTS`             | A wallet with that name already exists            |
| `-37` | `RPC_WALLET_BLANK`                      | Navio: the wallet has no BLSCT seed or keys (blank, or private keys disabled), e.g. from `getblsctseed` or `getblsctauditkey` |

### Navio-specific messages

| Message (prefix) | Code | Meaning |
| ---------------- | ---- | ------- |
| `This network only supports confidential (BLSCT) transactions; …` | `-1` / `-4` | A transparent-only RPC on mainnet, testnet or `blsctregtest`. The message names the BLSCT alternative. See [BLSCT-only networks](../rpc/index.md#blsct-only-networks) |
| `This RPC does not support BLSCT (confidential) wallets: …` | `-4` | A transparent spend RPC called on a BLSCT wallet |
| `Invalid audit key: the view key or the spend key is not a valid key` | `-8` | `createwallet` `seed` of 160 hex characters that is not a valid audit key (master) |
| `Seed must be 64 (master) or 160 (view) characters long` | `-4` | `createwallet` `seed` of the wrong length |
| `Cannot combine 'blank' with 'seed', 'mnemonic' or 'mnemonic_passphrase'. …` | `-8` | Master |
| `Cannot combine 'disable_private_keys' with a master seed or 'mnemonic', …` | `-8` | Master; pass an audit key instead |
| `Wallet has no BLSCT seed (private keys are disabled)` | `-37` (`getblsctseed`), `-4` (`dumpmnemonic`) | Watch-only wallet |
| `Wallet has no BLSCT audit key (…)` | `-37` | `getblsctauditkey` on a keyless wallet (master; earlier releases returned `-1`) |
| `<arg> must be a 64-hex token id, followed by #<subid> for an NFT, or empty for NAV` | `-8` | Malformed token argument in the RFQ / order RPCs or a `createblsctrawtransaction` `token_id` |
| `RFQ has a quote being accepted; …` | `-1` | `cancelrfq` while an accept is in flight (master) |
| `Error: This wallet already uses SQLite` | `-4` | `migratewallet`: every navio wallet is already SQLite |
| `Method not found` | `-32601` | Calling a removed RPC (PSBT, external signer, `listblscttransactions`) |

## SDK errors

Throwable `Error` instances from `navio-sdk`. Message prefixes are stable:

| Prefix                          | Meaning                                                |
| ------------------------------- | ------------------------------------------------------ |
| `"insufficient funds"`          | Not enough UTXOs of the requested token                 |
| `"wallet is locked"`            | Call `keyManager.unlock(pw)` first                      |
| `"wrong password"`              | Passed to `unlock` / `changePassword`                   |
| `"backend not connected"`       | Not yet initialized, or connection dropped              |
| `"invalid address"`             | Malformed bech32m or wrong-network HRP                  |
| `"audit-only wallet"`           | Spend-path methods on an audit-key-only wallet          |
| `"sync error"`                  | Propagated from backend                                 |
| `"reorg"`                       | Reorg interrupted an operation; retry after sync        |
| `"database locked"`             | Another process holds the DB file                        |

## ElectrumX custom errors

From the Navio ElectrumX fork:

| Error                                 | Meaning                                                    |
| ------------------------------------- | ---------------------------------------------------------- |
| `MethodNotFoundError`                 | Client called a removed legacy DAO method                  |
| `invalid output_hash`                 | Client passed `txid:vout` instead of an `output_hash`      |
| `max_send exceeded`                   | `blockchain.block.get_range_txs_keys` result would exceed `MAX_SEND`; client should use returned `next_height` for pagination |

## Navio-blocks REST API errors

Standard HTTP status codes. Error body shape:

```json
{
    "statusCode": 404,
    "error":      "Not Found",
    "message":    "Block 999999 not found"
}
```

| Status | Common causes                                                 |
| ------ | ------------------------------------------------------------- |
| 400    | Invalid query parameter (e.g., non-numeric `height`)          |
| 404    | Block, tx, or output not found                                 |
| 429    | Rate-limited                                                  |
| 500    | Upstream failure (naviod down, DB locked)                     |
| 503    | Indexer not yet caught up to required height                  |
