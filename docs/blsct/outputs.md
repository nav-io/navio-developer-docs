# Output construction

Anatomy of a BLSCT output — how senders build it, what bytes go on chain, and what each field means.

## Inputs to output construction

The sender needs:

-   Recipient **double public key** $(V_r, S_r)$ — decoded from the recipient's bech32m address.
-   **Amount** $v_{\text{amt}}$ (integer satoshis, 64-bit).
-   Optional **memo** (UTF-8, typically ≤ 32 bytes).
-   Optional **token id** (null for NAV, 32 bytes for fungible, 40 bytes for NFT).
-   Freshly sampled **blinding factor** $r \in \mathbb{F}_r$.
-   Freshly sampled **amount blinding factor** $\gamma \in \mathbb{F}_r$.

## Derived values

From $r$ and the recipient DPK:

-   **Ephemeral public key** $R = r \cdot g_1 \in G_1$. 48 bytes. Stored in the output as `blsctData.ephemeralKey`.
-   **Shared point** $\eta = r \cdot V_r = v_r \cdot R$. This is the Diffie–Hellman point between sender and receiver; it is what drives the view-tag, the stealth-key tweak, and the range-proof message encoding.
-   **View tag** $\tau = \text{SHA256}(\eta).\text{GetUint64}(0) \;\&\; \text{0xFFFF}$. **2 bytes** (uint16). See `CalculateViewTag` in `src/blsct/wallet/helpers.cpp`.
-   **Stealth spend pubkey** $S' = S_r + \text{H}_s(\eta, \text{salt}{=}0) \cdot g_1$, where $\text{H}_s$ is `MclG1Point::GetHashWithSalt`. Stored as `blsctData.spendingKey`. Spending requires the scalar $s' = s + m_{a,i} + \text{H}_s(\eta, 0)$ (see [Key derivation → per-output keys](keys.md#per-output-keys)).
-   **Blinding helper** $B = r \cdot S_r \in G_1$ (called `blindingKey` in `CTxOutBLSCTData`). This is an intermediate Diffie–Hellman point that lets the receiver compute the shared point $\eta$ with a single scalar multiplication: $v_r \cdot B = v_r \cdot r \cdot S_r = r \cdot V_r = \eta$. Storing $B$ (instead of only $R$) saves the receiver one point multiplication per output during scanning, at the cost of an extra $G_1$ element on the wire.
-   **Amount blinding factor** $\gamma = \text{H}_s(\eta, \text{salt}{=}100)$ — *not* sampled freshly; it is deterministic from the shared point so the receiver can reconstruct the commitment opening without side-channel data. Computed at `txfactory_global.cpp:113` (`ret.gamma = nonce.GetHashWithSalt(100)`).

## The Pedersen commitment

$$
C \;=\; v_{\text{amt}} \cdot G \;+\; \gamma \cdot H \;\in\; G_1
$$

where $G$ is the amount generator for this output's `token_id` (so distinct token types are cryptographically separated) and $H$ is the fixed, shared randomness base. Both are derived by `GeneratorsFactory` with the `"proof-of-stake"` seed in `src/blsct/range_proof/generators.h`; their discrete logs are unknown. 48 bytes on the wire. This commitment is the first element (`Vs[0]`) of the range proof, not a separate output field.

## Amount and memo encoding

**Amounts are not stored as a separate ciphertext blob.** They are embedded inside the Bulletproofs+ range proof via the prover scalars $\alpha_{\text{hat}}$ and $\tau_x$:

-   The 64-bit amount `vs[0]` and a 64-bit user message `msg1` are packed as `(msg1 << 64) | vs[0]` and added to the range-proof blinding: $\alpha = \text{H}_s(\eta, 1) + \text{msg1\_vs0}$, producing $\alpha_{\text{hat}}$ in the proof (see `MsgAmtCipher::ComputeAlpha` in `range_proof_logic.cpp`).
-   A second 64-bit user message `msg2` (the memo) is carried additively in $\tau_x$: the prover adds `msg2` into the linear term of the weighted-inner-product response (`MsgAmtCipher::ComputeTauX`).
-   The amount blinding factor $\gamma = \text{H}_s(\eta, 100)$ is deterministic, so no $\gamma$ ciphertext is needed.

Amount recovery inverts these equations using the shared point $\eta$ (reconstructable from $v_r$ and $R$). See [amount recovery](amount-recovery.md) for the closed-form inversion and salt constants.

## Range proof

A Bulletproofs++ range proof over the amount committed in $C$ proves

$$
0 \le v_{\text{amt}} < 2^{64}.
$$

Proof size is logarithmic in the bit width — typically 600–700 bytes per output. See [range proofs](range-proofs.md).

## On-chain layout

`CTxOut` and `CTxOutBLSCTData` are defined in [`src/primitives/transaction.h`](https://github.com/nav-io/navio-core/blob/master/src/primitives/transaction.h). Canonical byte order is little-endian for integers.

### In-memory class layout

```
CTxOut                              (primitives/transaction.h:228)
├── nValue            CAmount       (int64; 0 for BLSCT outputs)
├── scriptPubKey      CScript       (varbytes; contains stealth spend script)
├── blsctData         CTxOutBLSCTData
├── tokenId           TokenId       (null / 32 bytes fungible / 40 bytes NFT)
└── predicate         blsct::VectorPredicate  (empty unless PREDICATE_MARKER set)

CTxOutBLSCTData                     (primitives/transaction.h:156)
├── spendingKey       MclG1Point    48 bytes  (S' — stealth spend pubkey)
├── ephemeralKey      MclG1Point    48 bytes  (R = r · g_1 — the "ephemeral" Diffie–Hellman pubkey)
├── blindingKey       MclG1Point    48 bytes  (B = r · S_{a,i} — DH pre-point; η = v·B is the shared point)
├── rangeProof        bulletproofs_plus::RangeProof<Mcl>   (Bulletproofs+)
└── viewTag           uint16_t      2 bytes   (τ; 16 bits, computed as `Hash(v·R) & 0xFFFF` — see `src/blsct/wallet/helpers.cpp:15`)
```

!!! warning "Field-name overloading"
    The `CTxOutBLSCTData::blindingKey` field is **not** the same thing as the "blinding key" scalar `r`. The field stores the G₁ point $r \cdot S_{a,i}$, an intermediate DH value. The name matches historic protocol usage; in current code the scalar `r` is called the *blinding scalar* or the *ephemeral scalar*, and its scalar·generator product $r \cdot g_1$ is the `ephemeralKey` field.

### Wire serialisation order

The `Serialize`/`Unserialize` methods (see `transaction.h:170-188` and `transaction.h:249` onward) emit fields in this order:

```
CTxOut wire form:

  if BLSCT_MARKER | TOKEN_MARKER | PREDICATE_MARKER | TRANSPARENT_VALUE_MARKER set:
    nValue            int64    = std::numeric_limits<CAmount>::max()  (sentinel)
    nFlags            uint64   combination of markers (0x1 BLSCT, 0x2 TOKEN, 0x4 PREDICATE, 0x8 TRANSPARENT_VALUE)
    if TRANSPARENT_VALUE_MARKER:
      nValue          int64    actual transparent value
  else:
    nValue            int64

  scriptPubKey       CScript
  [blsctData                           if BLSCT_MARKER:]
    rangeProof        Bulletproofs++ range proof
    spendingKey       48 bytes         (S')
    blindingKey       48 bytes         (B = r · S)
    ephemeralKey      48 bytes         (R = r · G)
    viewTag           uint16_t         (little-endian)
  [tokenId            TokenId          if TOKEN_MARKER]
  [predicate          VectorPredicate  if PREDICATE_MARKER]
```

There is no separate `outputHash` field on the wire — the hash is computed over the serialised output (see [Outpoint model](../concepts/outpoint.md)).

!!! note "Recipient DPK is not recoverable from an output"
    On-chain data gives observers only $R$, $B$, and $S' = S_r + \text{H}_s(\eta,0) \cdot g_1$. Because $\eta = r \cdot V_r = v_r \cdot R$ requires *either* $r$ (which only the sender held) or $v_r$ (the recipient's view private key), reversing $S'$ to obtain $S_r$ (and therefore the recipient's DPK $(V_r, S_r)$) is computationally infeasible without one of the two DH secrets. This is why explorers cannot display recipient addresses on output pages — **not a privacy-policy choice, a mathematical constraint**.

## TypeScript representation

The SDK and navio-blsct expose this as the `CTxOut` + `CTxOutBLSCTData` types. See the [blsct-lib transactions page](../blsct-lib/transactions.md) and the auto-generated [SDK type reference](../sdk/api/README.md).

```ts
interface WalletOutput {
    outputHash:  string;     // 64-hex
    txHash:      string;
    outputIndex: number;
    blockHeight: number;
    amount:      bigint;     // satoshis, recovered
    memo:        string | null;
    tokenId:     string | null;   // 64 hex (fungible) or 80 hex (NFT) or null (NAV)
    blindingKey: string;     // B = r · S
    spendingKey: string;     // S'
    isSpent:     boolean;
    // ...
}
```

## Privacy invariants

-   **No address reuse on-chain.** Two outputs to the same recipient have different $S'$ (different $\sigma$ → different tweak).
-   **Amount hidden** from everyone except the receiver.
-   **Token id partially visible.** The token id (for non-NAV outputs) is in cleartext in the output; amounts remain confidential. This is a deliberate tradeoff — without it, the chain could not distinguish "100 TokenA" from "100 TokenB" for balance verification.
-   **Memo confidential** — only the receiver can decrypt.
-   **View tag is not a privacy leak in practice** — a 2-byte (16-bit) tag only tells an attacker that *1 in 65 536* outputs might match a given target view key by collision, which is too noisy to be useful.
