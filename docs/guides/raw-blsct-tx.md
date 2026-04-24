# Build and broadcast a raw BLSCT transaction

End-to-end without the SDK high-level helpers. Useful when you need custom scripts (HTLC, multi-party), non-standard coin selection, or when debugging a failed send.

The flow mirrors Bitcoin's `createrawtransaction` → `fundrawtransaction` → `signrawtransactionwithwallet` → `sendrawtransaction`, but with BLSCT-aware RPCs.

## 0. Prerequisites

-   Running `naviod` with RPC enabled.
-   A wallet with some spendable NAV or tokens.

## 1. Create an unsigned raw tx

```bash
navio-cli -testnet createblsctrawtransaction \
    '[]' \
    '[{"address":"tnav1...recipient...", "amount": 1.0}]'
```

First arg is the input array (empty = let `fundblsctrawtransaction` pick). Second is outputs. Returns unsigned raw tx hex.

You can supply explicit inputs when you need to spend specific outputs:

```bash
navio-cli -testnet createblsctrawtransaction \
    '[{"output_hash":"abc123..."}]' \
    '[{"address":"tnav1...", "amount":1.0}]'
```

Inputs reference `output_hash` directly — Navio does not use `txid:vout`. See [outpoint model](../concepts/outpoint.md).

## 2. Fund the tx

If you didn't specify inputs (or specified too few):

```bash
navio-cli -testnet fundblsctrawtransaction "<raw-hex>"
```

Returns a funded raw tx (inputs added, change output generated) and the selected fee.

## 3. Sign

```bash
navio-cli -testnet signblsctrawtransaction "<funded-hex>"
```

Returns the signed hex plus a `complete: true|false` flag. If `false`, inspect the `errors` field — likely inputs the wallet cannot sign (e.g., script paths not covered by the wallet's keys).

## 4. Decode (optional) to inspect

```bash
navio-cli -testnet decodeblsctrawtransaction "<signed-hex>"
```

Returns a full JSON view:

```json
{
  "txid": "...",
  "vin":  [{"prev_out": "...", "script_sig": "..."}],
  "vout": [
    {
      "value":       0,
      "scriptPubKey": {...},
      "tokenId":      null,
      "blsctData": {
        "blindingKey": "...",
        "viewTag":     17,
        "spendingKey": "...",
        "rangeProofSize": 675
      },
      "outputHash":   "..."
    },
    ...
  ],
  "locktime":       0,
  "balanceProofSize": 192,
  "txSignatureSize":  48
}
```

## 5. Broadcast

```bash
navio-cli -testnet sendrawtransaction "<signed-hex>"
```

Returns the txid.

## Locking inputs

If you build partial transactions for aggregation, mark the inputs as locked so the wallet doesn't re-select them:

```bash
# lock
navio-cli -testnet unlockblsctoutpoint "abc123..."   # misnomer — unlock releases
```

See [`unlockblsctoutpoint`](../rpc/blsct.md#unlockblsctoutpoint).

## Balance proofs on partial tx

For aggregated-swap flows where you need to prove a partial transaction honours a specific balance, use [`createblsctbalanceproof`](../rpc/blsct.md#createblsctbalanceproof).

## Scripts + `OP_BLSCHECKSIG`

Custom scripts (HTLC, multi-sig-like patterns) go in the output's `scriptPubKey` field. The wallet builds a BLSCT output addressed to a script hash, and spending is governed by stack + script rather than a stealth spend key.

Building the script itself is done outside `createblsctrawtransaction` — you compile the hex (e.g., via `navio-tx` or programmatically with [navio-blsct `Script`](../blsct-lib/primitives.md#script)) and pass the output as a raw scriptPubKey.

For full examples see the [atomic swaps walkthrough](atomic-swaps.md).

## Common errors

| Error                                       | Cause                                                          |
| ------------------------------------------- | -------------------------------------------------------------- |
| `Insufficient funds`                        | Wallet doesn't have enough of the requested tokenId            |
| `Could not find output`                     | `output_hash` in inputs is unknown — check wallet sync state    |
| `Incomplete signatures`                     | Wallet doesn't hold keys for every input — sign elsewhere       |
| `Transaction too large`                     | Hit the 4 MB block size limit (mainnet)                        |
| `Non-final transaction`                     | Locktime not reached; broadcast again later                     |
| `Insufficient fee`                          | Mempool min-fee rose; run `fundblsctrawtransaction` again        |

## SDK equivalent

The SDK wraps all four steps in `client.sendTransaction` / `client.sendToken` / etc. The raw flow is only needed for custom scripts, partial/aggregated transactions, offline signing, or debugging.
