# Build and broadcast a raw BLSCT transaction

End-to-end without the SDK high-level helpers. Useful when you need custom scripts (HTLC, multi-party), non-standard coin selection, or when debugging a failed send.

The flow mirrors Bitcoin's `createrawtransaction` → `fundrawtransaction` → `signrawtransactionwithwallet` → `sendrawtransaction`, but with BLSCT-aware RPCs. The transparent RPCs are refused on mainnet, testnet and `blsctregtest` (see [BLSCT-only networks](../rpc/index.md#blsct-only-networks)), and Navio has no PSBT RPCs.

## 0. Prerequisites

-   Running `naviod` with RPC enabled.
-   A BLSCT wallet with some spendable NAV or tokens.

## 1. Create an unsigned raw tx

```bash
navio-cli -testnet createblsctrawtransaction \
    '[]' \
    '[{"address":"tnv1...recipient...", "amount": 100000000}]'
```

First arg is the input array (empty = let `fundblsctrawtransaction` pick). Second is outputs. `amount` is in **navoshis** (`1 NAV = 100000000`). Returns unsigned raw tx hex.

You can supply explicit inputs when you need to spend specific outputs:

```bash
navio-cli -testnet createblsctrawtransaction \
    '[{"outid":"abc123..."}]' \
    '[{"address":"tnv1...", "amount":100000000}]'
```

Inputs reference an output by its output hash (`outid`) — Navio does not use `txid:vout`. See [outpoint model](../concepts/outpoint.md). With only `outid`, the wallet fills in the value, gamma and spending key from its own records, and fails with `Output <outid> not found in wallet` if it does not hold the output.

Each output can also carry:

| Field | Meaning |
| ----- | ------- |
| `memo` | Text the recipient can read |
| `token_id` | Token to send: the 64-hex token id, or `<token id>#<subid>` for an NFT (on master, after v0.2.2); empty for NAV |
| `script` | Raw output script hex |
| `type` | `"atomic_swap"` for an HTLC output (with `address_a`, `address_b`, `hash`, `locktime`), see [atomic swaps](atomic-swaps.md) |

The optional third argument sets the transaction type: `normal` (default), `create_token`, `mint_token` or `mint_nft`.

## 2. Fund the tx

If you didn't specify inputs (or specified too few):

```bash
navio-cli -testnet fundblsctrawtransaction "<raw-hex>"
```

Returns the funded raw tx hex: inputs added and a change output generated. Optional arguments: `changeaddress`, `lock_unspents`, `fee` (navoshis) and `estimate_fee`. The fee is always raised to at least the consensus minimum (transaction weight × the network's BLSCT fee rate).

## 3. Sign

```bash
navio-cli -testnet signblsctrawtransaction "<funded-hex>"
```

Returns the signed transaction hex. A watch-only (audit-key) wallet cannot sign: the call fails because the wallet holds no spend key. Sign on the wallet that does.

## 4. Decode (optional) to inspect

```bash
navio-cli -testnet decodeblsctrawtransaction "<signed-hex>"
```

Returns a structured JSON view of the transaction:

```json
{
  "inputs": [
    {
      "outid": "abc123...",
      "value": 100000000,
      "gamma": "...",
      "is_staked_commitment": false
    }
  ],
  "outputs": [
    {
      "scriptAddress": "tnv1...",
      "amount": 1.0,
      "amount_navoshi": 100000000,
      "blinding_key": "...",
      "outputHash": "...",
      "gamma": "...",
      "scriptPubKey": "...",
      "spending_key": "..."
    },
    ...
  ],
  "fee": 125000
}
```

`fee` is in navoshis.

## 5. Broadcast

```bash
navio-cli -testnet sendrawtransaction "<signed-hex>"
```

Returns the txid.

## Locking inputs

If you build partial transactions for aggregation, lock the inputs so the wallet doesn't re-select them: pass `lock_unspents=true` to `fundblsctrawtransaction`. Release a locked input with `unlockblsctoutpoint`:

```bash
navio-cli -testnet unlockblsctoutpoint "abc123..."
```

See [`unlockblsctoutpoint`](../rpc/blsct.md#unlockblsctoutpoint).

## Balance proofs on partial tx

For aggregated-swap flows where you need to prove a partial transaction honours a specific balance, use [`createblsctbalanceproof`](../rpc/blsct.md#createblsctbalanceproof).

## Scripts + `OP_BLSCHECKSIG`

Custom scripts (HTLC, multi-sig-like patterns) go in the output's `script` field. The wallet builds a BLSCT output addressed to a script hash, and spending is governed by stack + script rather than a stealth spend key.

Building the script itself is done outside `createblsctrawtransaction` — you compile the hex (e.g., via `navio-tx` or programmatically with [navio-blsct `Script`](../blsct-lib/primitives.md#script)) and pass it as the output's `script`.

For full examples see the [atomic swaps walkthrough](atomic-swaps.md).

## Common errors

| Error                                       | Cause                                                          |
| ------------------------------------------- | -------------------------------------------------------------- |
| `Insufficient funds: found N candidate outputs …` | Wallet doesn't have enough of the requested token          |
| `Output <outid> not found in wallet`        | `outid` in inputs is unknown to this wallet — check wallet sync state, or pass `value`, `gamma` and `spending_key` explicitly |
| `token_id must be a 64-hex token id, …`     | Malformed `token_id` (NFTs use `<token id>#<subid>`)           |
| `Each output must include an amount` / `Invalid amount, must be positive` | Missing or non-positive `amount`        |
| `Transaction deserialization failed`        | The hex passed to fund/sign/decode is not a BLSCT transaction  |
| `Could not converge BLSCT fund transaction fee` | Fee estimation did not settle; simplify the inputs/outputs |

## SDK equivalent

The SDK wraps all four steps in `client.sendTransaction` / `client.sendToken` / etc. The raw flow is only needed for custom scripts, partial/aggregated transactions, offline signing, or debugging.
