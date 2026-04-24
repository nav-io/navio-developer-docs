# Opcodes

Script opcode reference. Navio inherits Bitcoin's Script language and adds BLSCT-specific opcodes.

## Navio-specific

### `OP_BLSCHECKSIG` — `0xb3` (formerly `OP_NOP4`)

Stack: `(pubkey -- bool)`

Verifies a BLS12-381 signature against a public key. Replaces `OP_CHECKSIG` in BLSCT-aware scripts (atomic swaps, custom HTLC flows).

```
<pubkey> OP_BLSCHECKSIG
```

| Field          | Requirement                                     |
| -------------- | ----------------------------------------------- |
| Public key     | 48 bytes, compressed $G_1$ point                |
| Signature      | 48 bytes, compressed $G_1$ signature              |
| Return value   | `1` (true) on valid signature, `0` otherwise     |

The signature is pulled from the scriptSig / witness of the spending input; the opcode itself consumes the public key from the stack and pushes a boolean.

Usage pattern in an HTLC:

```
OP_IF
    OP_HASH160 <hash_A> OP_EQUALVERIFY
    <counterparty_bls_pubkey> OP_BLSCHECKSIG
OP_ELSE
    <timelock> OP_CHECKLOCKTIMEVERIFY OP_DROP
    <self_bls_pubkey> OP_BLSCHECKSIG
OP_ENDIF
```

See [atomic swaps](../concepts/atomic-swaps.md) for the full context.

!!! note "Opcode byte value"
    The source of truth is [`src/script/script.h`](https://github.com/nav-io/navio-core/blob/master/src/script/script.h) in navio-core. Historical Navcoin documentation and some third-party references list `OP_BLSCHECKSIG` as `0xbb`; the current consensus value is `0xb3` (reusing the former `OP_NOP4`). Always verify against the source for the release you target.

## Inherited from Bitcoin Script

Standard Bitcoin Script opcodes are supported. The complete table is maintained in [`src/script/script.h`](https://github.com/nav-io/navio-core/blob/master/src/script/script.h). Common ones:

### Constants

| Opcode       | Hex  | Effect                                           |
| ------------ | ---- | ------------------------------------------------ |
| `OP_0`       | 0x00 | Push 0 (empty string)                             |
| `OP_1NEGATE` | 0x4f | Push -1                                           |
| `OP_1`…`OP_16` | 0x51–0x60 | Push 1–16                                   |
| `OP_PUSHDATA1/2/4` | 0x4c-0x4e | Push next N bytes                         |

### Flow control

| Opcode       | Hex  | Effect                                           |
| ------------ | ---- | ------------------------------------------------ |
| `OP_IF`      | 0x63 | Conditional begin                                |
| `OP_NOTIF`   | 0x64 | Inverted conditional                             |
| `OP_ELSE`    | 0x67 | Else branch                                      |
| `OP_ENDIF`   | 0x68 | End conditional                                   |
| `OP_VERIFY`  | 0x69 | Fail if top of stack is false                    |
| `OP_RETURN`  | 0x6a | Mark output as provably unspendable (burn)       |

### Stack

| Opcode         | Hex  |
| -------------- | ---- |
| `OP_DUP`       | 0x76 |
| `OP_DROP`      | 0x75 |
| `OP_SWAP`      | 0x7c |
| `OP_2DUP`      | 0x6e |
| `OP_TOALTSTACK` | 0x6b |
| `OP_FROMALTSTACK` | 0x6c |

### Bitwise / arithmetic

| Opcode        | Hex  |
| ------------- | ---- |
| `OP_EQUAL`    | 0x87 |
| `OP_EQUALVERIFY` | 0x88 |
| `OP_ADD`      | 0x93 |
| `OP_SUB`      | 0x94 |
| `OP_BOOLAND`  | 0x9a |
| `OP_NUMEQUAL` | 0x9c |

### Cryptographic

| Opcode                | Hex  | Notes                                                            |
| --------------------- | ---- | ---------------------------------------------------------------- |
| `OP_RIPEMD160`        | 0xa6 |                                                                  |
| `OP_SHA1`             | 0xa7 |                                                                  |
| `OP_SHA256`           | 0xa8 |                                                                  |
| `OP_HASH160`          | 0xa9 | SHA256 then RIPEMD160. Used in HTLCs.                            |
| `OP_HASH256`          | 0xaa | Double SHA256                                                    |
| `OP_CODESEPARATOR`    | 0xab | Rarely used                                                      |
| `OP_CHECKSIG`         | 0xac | Traditional ECDSA signature check                                |
| `OP_CHECKSIGVERIFY`   | 0xad |                                                                  |
| `OP_CHECKMULTISIG`    | 0xae | Legacy multisig                                                  |
| `OP_CHECKMULTISIGVERIFY` | 0xaf |                                                              |
| `OP_BLSCHECKSIG`      | 0xb3 | **Navio-specific** — BLS signature check                         |

### Timelock

| Opcode                   | Hex  |
| ------------------------ | ---- |
| `OP_CHECKLOCKTIMEVERIFY` | 0xb1 |
| `OP_CHECKSEQUENCEVERIFY` | 0xb2 |

## Unsupported / repurposed

Some `OP_NOPx` opcodes have been repurposed:

-   `OP_NOP4` → `OP_BLSCHECKSIG` (`0xb3`).

Any other `OP_NOPx` remains a no-op and passes validation. Custom scripts using them as markers still work.
