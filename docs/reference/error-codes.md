# Error codes

## JSON-RPC standard

Per [JSON-RPC 2.0 spec](https://www.jsonrpc.org/specification#error_object):

| Code          | Meaning                                 |
| ------------- | --------------------------------------- |
| `-32700`      | Parse error (invalid JSON)              |
| `-32600`      | Invalid Request                         |
| `-32601`      | Method not found                        |
| `-32602`      | Invalid params                          |
| `-32603`      | Internal error                          |

## Bitcoin-derived

Source: [`src/rpc/protocol.h`](https://github.com/nav-io/navio-core/blob/master/src/rpc/protocol.h) in navio-core.

### General

| Code   | Name                          | When                                                              |
| ------ | ----------------------------- | ----------------------------------------------------------------- |
| `-1`   | `RPC_MISC_ERROR`              | Miscellaneous                                                     |
| `-2`   | `RPC_TYPE_ERROR`              | Unexpected type                                                   |
| `-3`   | `RPC_INVALID_ADDRESS_OR_KEY`  | Bad address, unknown token id, wrong key                          |
| `-4`   | `RPC_OUT_OF_MEMORY`           | Rare                                                              |
| `-5`   | `RPC_INVALID_PARAMETER`       | Parameter failed validation                                       |
| `-7`   | `RPC_CLIENT_NOT_CONNECTED`    | RPC client lost node connection                                   |
| `-8`   | `RPC_INVALID_PARAMETER`       | Invalid, missing, or duplicate parameter                          |
| `-9`   | `RPC_CLIENT_IN_INITIAL_DOWNLOAD` | Node still in IBD                                             |
| `-10`  | `RPC_CLIENT_NODE_ALREADY_ADDED`                                                                      |
| `-11`  | `RPC_CLIENT_NODE_NOT_ADDED`                                                                           |
| `-25`  | `RPC_VERIFY_ERROR`            | Transaction verification failed                                    |
| `-26`  | `RPC_VERIFY_REJECTED`         | Transaction rejected by consensus/policy                          |
| `-27`  | `RPC_VERIFY_ALREADY_IN_CHAIN` | Tx already in chain                                               |
| `-28`  | `RPC_IN_WARMUP`               | RPC subsystem still starting                                      |

### Wallet

| Code  | Name                                    | When                                              |
| ----- | --------------------------------------- | ------------------------------------------------- |
| `-4`  | `RPC_WALLET_ERROR`                      | Generic wallet failure                             |
| `-5`  | `RPC_WALLET_INSUFFICIENT_FUNDS`         | Not enough funds                                  |
| `-6`  | `RPC_WALLET_INVALID_ACCOUNT_NAME`                                                             |
| `-11` | `RPC_WALLET_KEYPOOL_RAN_OUT`                                                                   |
| `-12` | `RPC_WALLET_UNLOCK_NEEDED`              | Call `walletpassphrase` first                     |
| `-14` | `RPC_WALLET_PASSPHRASE_INCORRECT`                                                              |
| `-15` | `RPC_WALLET_WRONG_ENC_STATE`            | Encrypted vs unencrypted mismatch                 |
| `-16` | `RPC_WALLET_ENCRYPTION_FAILED`                                                                 |
| `-17` | `RPC_WALLET_ALREADY_UNLOCKED`                                                                  |
| `-18` | `RPC_WALLET_NOT_FOUND`                                                                          |
| `-19` | `RPC_WALLET_NOT_SPECIFIED`                                                                      |

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
