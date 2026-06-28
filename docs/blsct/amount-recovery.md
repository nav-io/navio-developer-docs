# Amount recovery

Once a wallet confirms that an output is addressed to one of its sub-addresses (see [detection](detection.md)), it must recover the **amount**. The commitment $C = v_{\text{amt}} \cdot G + \gamma \cdot H$ hides the amount from any observer without the blinding factor $\gamma$, but the amount is **not encrypted as a separate ciphertext on the wire**. It is embedded inside the Bulletproofs+ range proof itself, and recovered by inverting two linear equations that the prover set up during proof generation.

The recovery routine lives in `RangeProofLogic<T>::RecoverAmounts` (`src/blsct/range_proof/bulletproofs_plus/range_proof_logic.cpp:RecoverAmounts`) and `MsgAmtCipher<T>::Decrypt`.

## Nonce

The *nonce* used by recovery is the shared Diffie–Hellman **point** $\eta \in G_1$:

$$
\eta \;=\; r \cdot V_{a,i} \;=\; v \cdot R \;=\; v \cdot r \cdot g_1.
$$

The sender has $r$ and $V_{a,i}$; the receiver has $v$ and $R$. Both compute the same $\eta$. In code, `CalculateNonce(blindingKey, viewKey)` returns `blindingKey * viewKey` as a `MclG1Point` (`src/blsct/wallet/helpers.cpp`). All subsequent "sub-nonces" are derived deterministically via `\eta.\text{GetHashWithSalt}(\text{salt})`:

| Salt | Role in the range proof                                                  |
| ---- | ------------------------------------------------------------------------ |
| 1    | Proof blinding scalar $\text{nonce}_1$ added into $\alpha$.              |
| 2    | Coefficient $\tau_1$ of the linear term of the polynomial commitment.    |
| 3    | Coefficient $\tau_2$ of the quadratic term of the polynomial commitment. |
| 100  | Amount commitment blinding $\gamma$ for the output's single value $v_0$. |

## What the prover embeds

During `Prove` the sender packs:

-   The first 23 bytes of the user message (`msg1`, `Setup::message_1_max_size`) and the 64-bit amount `vs[0]` into a single scalar:

    $$
    \text{msg1\_vs0} \;=\; (\text{msg1} \ll 64) \;\vert\; \text{vs}[0] \quad (\bmod\, r)
    $$

-   Sets $\alpha = \text{nonce}_1 + \text{msg1\_vs0}$, producing the proof's $\alpha_{\text{hat}}$ after the outer-round weighted sum:

    $$
    \alpha_{\text{hat}} \;=\; \text{nonce}_1 \;+\; \text{msg1\_vs0} \;+\; \Bigl(z^{(2)}_{\text{asc}} \cdot \gamma\Bigr) \cdot y^{mn+1}
    $$

    where $z^{(2)}_{\text{asc}}$ and $y^{mn+1}$ come from `ComputePowers(y, z, m, n)` — the deterministic Fiat–Shamir challenges of the proof.

-   Packs the remainder of the message (`msg2`, bytes past the first 23 — the memo continuation) into $\tau_x$:

    $$
    \tau_x \;=\; \tau_2 \cdot y^2 \;+\; (\tau_1 + \text{msg2}) \cdot y \;+\; z^2 \cdot \gamma.
    $$

## Recovery by the receiver

Given the on-chain $R, B$ (or just $R$ and $v$), the stored $\alpha_{\text{hat}}, \tau_x$ (from the range proof), and the commitment $\text{Vs}[0] = C$, the receiver computes:

```text
η            = v · R                                  (G1 point)
γ            = η.GetHashWithSalt(100)                 (scalar)
nonce_1      = η.GetHashWithSalt(1)
τ_1          = η.GetHashWithSalt(2)
τ_2          = η.GetHashWithSalt(3)

# Re-derive Fiat–Shamir challenges y, z from the proof transcript.
(z_asc_pows, y_mn_plus_1) = ComputePowers(y, z, m=1, n=64)
α_hat_sum    = (z_asc_pows · γ) · y_mn_plus_1

# Recover packed msg1 || vs[0]
msg1_vs0     = α_hat - nonce_1 - α_hat_sum            # scalar subtraction in F_r
vs[0]        = msg1_vs0 & (2^64 - 1)                  # low 64 bits = amount
msg1         = msg1_vs0 >> 64                         # high 64 bits = user msg1

# Recover msg2 from τ_x
msg2         = (τ_x - τ_2 · y² - z² · γ) · y⁻¹ - τ_1
```

(see `range_proof_logic.cpp:RecoverAmounts` lines 577–635 and `MsgAmtCipher<T>::Decrypt`.)

The wallet then verifies the commitment re-opens correctly:

```
C_check = vs[0] · G  +  γ · H
assert C_check == output.blsctData.rangeProof.Vs[0]
```

If the check fails, the output is not this wallet's (the view tag was a 1-in-65 536 false positive, or the sender constructed a malformed output). The wallet discards and moves on.

## Memo recovery

The recovered message is the concatenation of `msg1` (the first 23 bytes, unpacked from `msg1_vs0 >> 64`) and `msg2` (the remainder, unpacked from $\tau_x$) — both via `GetVch(true)`. There is **no separate memo ciphertext on the wire** and no stream-cipher keystream — `msg1` rides in $\alpha_{\text{hat}}$ alongside the amount, `msg2` in $\tau_x$. Total message capacity is `Setup::max_message_size = 54` bytes (`message_1_max_size = 23` in `msg1` plus the rest in `msg2`).

## RPC for third-party recovery

A trusted auditor, or a recipient who lost access to their wallet but has the transaction's output hash and a nonce, can use:

-   [`getblsctrecoverydata`](../rpc/blsct.md#getblsctrecoverydata) — derive the recovery data for outputs in a transaction given wallet access.
-   [`getblsctrecoverydatawithnonce`](../rpc/blsct.md#getblsctrecoverydatawithnonce) — given a specific shared nonce (e.g., recovered from a sender), decrypt just those outputs.
-   [`deriveblsctnonce`](../rpc/blsct.md#deriveblsctnonce) — compute the shared nonce from a destination address and the sender's blinding key.

These commands are how watch-only and audit workflows reconstruct amounts without the spend key.

## SDK

```ts
// High-level: sync already recovers amounts into WalletOutput.amount
const utxos = await client.getUnspentOutputs();
for (const utxo of utxos) {
    console.log(utxo.amount, 'sats');   // already recovered
}

// Low-level: recover manually from a given blinding key + output
const km = client.getKeyManager();
const nonce = km.calculateNonce(output.blindingKey);
// use navio-blsct primitives to decrypt the amount
```

See [`navio-blsct` AmountRecoveryReq/Res](../blsct-lib/privacy.md#amount-recovery) for the library primitives.

## Edge cases

-   **Change outputs** recover identically — the sender addresses change to a sub-address in their own pool `-1`.
-   **Audit recovery** — a wallet restored from audit key can recover every amount because $v$ determines $\sigma$.
-   **Corrupted outputs** — if the commitment does not match the decrypted amount, wallet treats the output as not addressed to it.
-   **Zero-amount outputs** — valid (e.g. `OP_RETURN` outputs and some coinstake markers have `vs[0] = 0`). The commitment is $0 \cdot G + \gamma \cdot H = \gamma \cdot H$, i.e. a point with a hidden discrete log under the shared randomness base.
