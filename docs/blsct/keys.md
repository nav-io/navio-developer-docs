# Key derivation

Every Navio wallet derives its entire key material from a single master seed using **EIP-2333**, the IETF-standard hierarchical key-derivation tree for BLS12-381 (the same scheme Ethereum 2.0 validators use). This page documents the exact derivation paths and the relationships between view keys, spend keys, blinding keys, token keys, sub-addresses, and audit keys.

## Master seed → master scalar

1.  **Entropy source.** 128 or 256 bits of entropy (BIP-39 mnemonic, or raw).
2.  **EIP-2333** — a tree of Lamport-signature-based derivation functions combined with HKDF-SHA256 produces child scalars uniformly in $\mathbb{F}_r$. The root function is `derive_master_SK`; each child step is `derive_child_SK(parent, index)` (see `src/blsct/eip_2333/`). Derivation is collision-resistant and produces scalars in $[0, r)$.
3.  Master scalar $m$ is stored encrypted or plaintext in the wallet DB (`master_seed` table).

## Derivation tree

Navio derives four scalars from the master seed, organised into a two-level EIP-2333 tree (see `src/blsct/wallet/helpers.cpp`):

```
m                                                          (master seed scalar)
└── child = derive_child_SK(m, 130)                        (FromSeedToChildKey)
    ├── tx     = derive_child_SK(child, 0)                 (FromChildToTransactionKey)
    │   ├── v  = derive_child_SK(tx,    0)                 (FromTransactionToViewKey)
    │   └── s  = derive_child_SK(tx,    1)                 (FromTransactionToSpendKey)
    ├── b      = derive_child_SK(child, 1)                 (FromChildToBlindingKey)
    └── t      = derive_child_SK(child, 2)                 (FromChildToTokenKey)
```

Each leaf is a scalar in $\mathbb{F}_r$:

-   **View scalar** $v$ — scans for incoming outputs; recovers stealth spending keys and amounts.
-   **Spend scalar** $s$ — authorises spending (signs per-input stealth signatures).
-   **Blinding scalar** $b$ — seeds per-output randomness (blinding factors $\gamma$, ephemeral $r$, range-proof nonces).
-   **Token scalar** $t$ — signs `createtoken` / `createnft` / `minttoken` / `mintnft` transactions.

The corresponding pubkeys are $V = v \cdot g_1$, $S = s \cdot g_1$, $T = t \cdot g_1 \in G_1$, where $g_1$ is the base point.

The pair $(V, S)$ — or equivalently $(v, S)$ — is the information an auditor needs to see (but not spend) the wallet's incoming outputs. See [audit key](#audit-key).

## Sub-addresses

A sub-address is a deterministic derivation indexed by `(account, address)`, computed in `SubAddress::SubAddress(viewKey, spendKey, subAddressId)` in `src/blsct/wallet/address.cpp`:

$$
m \;=\; \text{SHA256}\!\bigl(\text{"SubAddress\textbackslash 0"} \,\|\, v \,\|\, \text{account} \,\|\, \text{address}\bigr) \bmod r
$$

$$
M = m \cdot g_1, \qquad D = S + M, \qquad C = v \cdot D
$$

The sub-address DPK is then stored as $(C, D)$ — i.e. $(V_{a,i}, S_{a,i})$ where:

```
sub_spend_pubkey S_{a,i} = S + m · g_1
sub_view_pubkey  V_{a,i} = v · S_{a,i}          // derived from v for unlinkability
```

The tuple $(V_{a,i}, S_{a,i})$ is the **double public key** that becomes the on-wire address via bech32m encoding. See [double public key](double-public-key.md).

Account indexing convention (by Navio SDK and navio-core):

| `account` | Pool purpose                                |
| :-------: | ------------------------------------------- |
|     0     | Main receiving                              |
|    -1     | Change                                      |
|    -2     | Staking (coinstake rewards)                 |

`index` increments monotonically within a pool. Wallets maintain a *sub-address pool* (a look-ahead window of unused indices) so incoming outputs can be detected before the wallet has explicitly exposed the address.

## Per-output keys

For each output sent to a sub-address, the sender picks a random scalar $r \in \mathbb{F}_r$ (the *ephemeral* / blinding factor, derived from the sender's blinding key $b$ and a per-output counter) and derives:

-   **Ephemeral public key** $R = r \cdot g_1$ — stored in the output as `ephemeralKey`.
-   **Stored blinding helper** $B = r \cdot S_{a,i}$ — stored in the output as `blindingKey`.
-   **Shared point** $\eta = v \cdot B = r \cdot V_{a,i}$ — the Diffie–Hellman point shared between sender (who knows $r$) and receiver (who knows $v$). In the wallet code path this is what `CalculateNonce(blindingKey, viewKey)` computes.
-   **View tag** $\tau = \text{SHA256}\bigl(R \cdot v\bigr).\text{GetUint64}(0) \,\&\, \text{0xFFFF}$ — a **2-byte** (16-bit) optimisation for scanning. Computed by `CalculateViewTag`.
-   **Stealth spend pubkey** $S' = S_{a,i} + \text{H}_s(\eta, \text{salt}{=}0) \cdot g_1$, where $\text{H}_s(\cdot, \text{salt}{=}0)$ is `MclG1Point::GetHashWithSalt(0)` applied to the shared point $\eta$. Spending this output requires the stealth private scalar

    $$
    s' \;=\; s \,+\, m_{a,i} \,+\, \text{H}_s(\eta, \text{salt}{=}0)
    $$

    computed in `CalculatePrivateSpendingKey` (where $m_{a,i}$ is the sub-address tweak from the previous section). The corresponding pubkey $s' \cdot g_1$ is what the output stores as the stealth spending key.

The sender stores in the output: $R$ (`ephemeralKey`), $B$ (`blindingKey`), $\tau$ (view tag), the stealth spend pubkey, the Pedersen commitment $C = v_{\text{amt}} \cdot G + \gamma \cdot H$ (see [range proofs](range-proofs.md) for the commitment form), the range proof (which embeds the encrypted amount and memo in the proof's $\alpha_{\text{hat}}$ and $\tau_x$ scalars — see [amount recovery](amount-recovery.md)), and the token id.

## Receiver-side recovery

Using $v$ and the look-ahead set of $S_{a,i}$ for each tracked sub-address, the receiver tests every output on the chain:

1.  Compute the shared point $\eta_{\text{test}} = v \cdot B$.
2.  Compute $\tau_{\text{test}} = \text{SHA256}(\eta_{\text{test}}).\text{GetUint64}(0) \,\&\, \text{0xFFFF}$.
3.  If $\tau_{\text{test}} \ne \tau$ (the stored view tag), skip — not this wallet's output.
4.  Otherwise, compute $S_{a,i}^{\text{derived}} = S'_{\text{stored}} - \text{H}_s(\eta, \text{salt}{=}0) \cdot g_1$ and test it against every tracked sub-address spend pubkey (see `CalculateHashId` in `helpers.cpp`). On match, this output is ours.
5.  Recover amount via range-proof-based decryption (see [amount recovery](amount-recovery.md)).

This is the primitive implemented by [`KeyManager.isMineByKeys`](../sdk/wallet.md#key-manager) and, under the hood, by `navio-blsct`'s C++ / WASM routines.

## Token keys

Token creators derive an independent token-signing key as a dedicated branch of the EIP-2333 tree:

```
t = derive_child_SK(child_key, 2)
T = t · g_1
```

(see `FromChildToTokenKey` in `helpers.cpp`). This key — not a per-token-id hash — is used to sign `createtoken` / `createnft` / `minttoken` / `mintnft` transactions. Per-token-id uniqueness is established by the `token_id` included in the signed message, not by rederiving a new scalar per token.

## Audit key

The **audit key** is the concatenation

```
audit_key_bytes = v (32 bytes, view scalar)  ||  S (48 bytes, spend pubkey in G_1)
```

(80 bytes = 160 hex chars). Produced by the [`getblsctauditkey`](../rpc/blsct.md#getblsctauditkey) RPC as `hex(v) || hex(S)`, zero-padded to 64 and 96 hex chars respectively (`src/wallet/rpc/backup.cpp:getblsctauditkey`). Holding the audit key lets its bearer:

-   Derive every sub-address the wallet has ever used (since $S$ is public and sub-address derivation uses only $v$ and $S$).
-   Compute $\sigma$ for every output and recover the amount.

It does **not** reveal $s$, so no spending is possible.

Audit keys are the primitive behind watch-only wallets. The SDK exposes [`keyManager.getAuditKeyHex()`](../sdk/wallet.md#audit-key) and [`restoreFromAuditKey`](../sdk/client.md#audit-key-restore); the RPC equivalent is [`getblsctauditkey`](../rpc/blsct.md#getblsctauditkey) and [`importblsctauditkey`](../rpc/blsct.md).

## BIP-39 mnemonic support

The SDK supports 12- and 24-word BIP-39 mnemonics. The mapping:

1.  Mnemonic → 512-bit seed via PBKDF2-HMAC-SHA512 (BIP-39 standard).
2.  Seed → master scalar $m \in \mathbb{F}_r$ via EIP-2333 `derive_master_SK`.
3.  From $m$ forward, identical to the raw-seed path (child → tx → view/spend, blinding, token — see [Derivation tree](#derivation-tree)).

This means a single mnemonic uniquely determines the entire wallet — including all sub-addresses, the audit key, and the token-signing key for any collection the wallet owns.
