# libblsct-bindings

**libblsct-bindings** exposes Navio's confidential-transaction primitives (`libblsct`) to multiple programming languages. It is the umbrella project that delivers `libblsct` as a first-class dependency outside the C++ codebase — so any application stack can build BLSCT transactions, derive keys, verify proofs, and interact with the protocol natively.

-   **Repository**: [nav-io/libblsct-bindings](https://github.com/nav-io/libblsct-bindings)
-   **License**: MIT

## Supported languages

| Language             | Package                                                                                | Latest   | Runtime                          | Status     |
| -------------------- | -------------------------------------------------------------------------------------- | -------- | -------------------------------- | ---------- |
| TypeScript / JavaScript | [`@nav-io/navio-blsct`](https://www.npmjs.com/package/@nav-io/navio-blsct) (npm)    | 1.3.0 (2026-10-16) | Node.js (native C++) + Browser (WASM) | Shipping |
| Python               | [`navio-blsct`](https://pypi.org/project/navio-blsct/) (PyPI)                          | 0.0.41 (2026-11-04) | CPython 3.x                 | Shipping   |
| C#                   | `NavioBlsct` ([`ffi/csharp`](https://github.com/nav-io/libblsct-bindings/tree/main/ffi/csharp)) | build from source | .NET 8 / .NET 10 / .NET Standard 2.1 | In repo, CI-tested |
| Rust                 | `navio-blsct` crate ([`ffi/rust`](https://github.com/nav-io/libblsct-bindings/tree/main/ffi/rust)) | build from source | Rust (Linux, macOS, Windows) | In repo, CI-tested |

The bindings do not have GitHub releases; versions are the package-registry versions above. Every binding builds `libblsct` from one shared navio-core pin (`ffi/navio-core.sha`), and can link a prebuilt library built for the same pin.

!!! note "C# and Rust packages"
    The C# binding is not yet on NuGet, and the `navio-blsct` crate on crates.io predates the current Rust binding. Build both from the repository.

## Planned languages

-   C — flat FFI surface for any host language that can dlopen a shared library.
-   Go — cgo-based binding.

Track language status in the upstream README: <https://github.com/nav-io/libblsct-bindings>.

## Recent changes

| Release | Binding | Changes |
| ------- | ------- | ------- |
| TS 1.1.20 | TypeScript | `UnsignedOutput.mintToken` — mint outputs are built with the same range-proof format as the rest of the transaction. |
| TS 1.2.0 | TypeScript | Built against navio-core with the supranational/blst backend. |
| TS 1.3.0 | TypeScript | [Stake delegation](transactions.md#stake-delegation) API for cold staking; `parseDataPredicateData`; `CTxOut.getScriptPubKeyHex()`; `CTx.generate(txIns, txOuts, changeAddr)`; `CTxOut.getSpendingKey()` / `getBlindingKey()` return `Point`. |
| Python 0.0.40 | Python | Stake-delegation output API (used by Navio Electrum 4.9.10+), DATA predicate payload reader, full `scriptPubKey` reader, change address for `CTx`; `CTxOut` spending / blinding keys are points. |
| Python 0.0.41 | Python | `set_unsigned_transaction_emit_fee_output` / `get_unsigned_transaction_emit_fee_output` at the SWIG level (`blsct.blsct`), to sign fee-0 aggregation cover candidates without a fee output (used by Navio Electrum 4.9.17+). Built against navio-core `7976768` ([#677](https://github.com/nav-io/navio-core/pull/677)). |

In the repository, the Rust binding also wraps the stake-delegation C API and reads DATA predicate payloads and full `scriptPubKey`s, and the C# binding is tested end to end for cold staking. The TypeScript build scripts in the repository export the emit-fee-output functions too, but no npm release ships them yet (1.3.0 predates them).

## libblsct C API changes in navio-core v0.3.0 {#libblsct-c-api-changes-in-navio-core-v030}

These change `libblsct`'s C header (`src/blsct/external_api/blsct.h`) in navio-core v0.3.0. They matter to anyone who links `libblsct` directly or maintains a binding.

!!! warning "Breaking: explicit message lengths"
    `build_range_proof`, `sign_message` and `verify_msg_sig` take the message as a pointer **and an explicit `size_t msg_len`** ([#714](https://github.com/nav-io/navio-core/pull/714)). Every consumer and binding must pass the new argument and be rebuilt against the new header.

    ```c
    BlsctRetVal* build_range_proof(const void* vp_uint64_vec, const BlsctPoint* blsct_nonce,
                                   const char* blsct_msg, size_t msg_len,
                                   const BlsctTokenId* blsct_token_id);
    const BlsctSignature* sign_message(const BlsctScalar* blsct_priv_key,
                                       const char* blsct_msg, size_t msg_len);
    bool verify_msg_sig(const BlsctPubKey* blsct_pub_key, const char* blsct_msg, size_t msg_len,
                        const BlsctSignature* blsct_signature);
    ```

    -   The message needs no NUL terminator and is never read past `msg_len`. It may be NULL only when `msg_len` is 0; NULL with a non-zero length makes `build_range_proof` return `BLSCT_FAILURE`, `sign_message` return NULL and `verify_msg_sig` return false.
    -   `sign_message` and `verify_msg_sig` sign and check all `msg_len` bytes, including NUL bytes. Before, a message was cut at its first NUL byte, so a signature over `"ab\0cd"` also verified for `"ab"`.
    -   `build_range_proof` returns `BLSCT_FAILURE` for a message containing a NUL byte, because amount recovery returns the message as a C string and would cut it there.

    The published bindings (TypeScript 1.3.0, Python 0.0.41) and the repository's current pin (`ffi/navio-core.sha` = `7976768`) predate this change and still use the NUL-terminated signatures. A bindings release that moves its pin to v0.3.0 has to adopt them.

**Fee-0 candidates without a fee output** ([#677](https://github.com/nav-io/navio-core/pull/677), additive). Light wallets can build the 1-input/1-output, fee-0 cover candidates a wallet serving `AGG_ANN` requests sends back:

```c
void set_unsigned_transaction_emit_fee_output(void* vp_unsigned_transaction, bool emit_fee_output);
bool get_unsigned_transaction_emit_fee_output(const void* vp_unsigned_transaction);
```

-   The default is `true`, so signing works as before. `get_…` returns `true` for a NULL handle.
-   With `false`, `sign_unsigned_transaction` emits neither the `OP_RETURN` fee output nor its fee signature. The inputs must balance the outputs exactly, and signing returns `BLSCT_FAILURE` if the fee is not 0. A candidate with a fee output is rejected by the requester's candidate pool.
-   `serialize_unsigned_transaction` (and the blobs `createblsctrawtransaction` / `signblsctrawtransaction` exchange) gains format **version 2**, which appends the flag. It is written only when the fee output is off, so every other unsigned transaction keeps the version 1 layout. Decoding rejects unknown format versions instead of misreading them.

## What all bindings expose

Every language surface covers the same core primitives — naming and idioms differ, semantics do not:

-   Curve arithmetic — scalars and $G_1$ points on BLS12-381.
-   Keys — private keys, public keys, double public keys, sub-addresses, HD derivation.
-   Transactions — `CTx`, `CTxIn`/`CTxIns`, `CTxOut`/`CTxOuts`, `CTxId`, `OutPoint`.
-   Privacy primitives — Pedersen commitments, range proofs, amount recovery.
-   Signatures — BLS aggregate signatures and verifications.
-   Network context — `setChain` / `BlsctChain` equivalents.

Each binding is generated from the same underlying SWIG interface (`swig/`) with a language-specific `ffi/<lang>/` wrapper. Bindings stay in lockstep with navio-core through a single pinned commit (`ffi/navio-core.sha`).

## Bindings by language

### TypeScript / JavaScript (`@nav-io/navio-blsct`)

Documentation in this section describes the TypeScript binding in detail — it is the most feature-complete at the moment and is what [navio-sdk](../sdk/index.md) consumes.

| Page                                              | Topic                                                          |
| ------------------------------------------------- | -------------------------------------------------------------- |
| [Installation](install.md)                        | Node install, browser bundler config, `loadBlsctModule()`      |
| [Primitives](primitives.md)                       | `Scalar`, `Point`, `Signature`, `Script`                       |
| [Keys](keys.md)                                   | `PublicKey`, `PublicKeys`, `DoublePublicKey`, `SubAddress`     |
| [Transactions](transactions.md)                   | `CTx`, `CTxIn`/`CTxIns`, `CTxOut`/`CTxOuts`, `CTxId`, `OutPoint`, stake delegation |
| [Privacy primitives](privacy.md)                  | `RangeProof`, `AmountRecoveryReq/Res`, `TokenId`, `TokenInfo`, `HashId` |
| [Network configuration](network.md)               | `setChain` / `getChain` / `BlsctChain`                         |
| [Memory model](memory.md)                         | `ManagedObj` lifetime, native vs WASM differences              |
| [API reference](api/README.md)                    | Auto-generated TypeDoc reference                               |

Two builds:

| Build    | Runtime         | Backing implementation              |
| -------- | --------------- | ----------------------------------- |
| Node.js  | v18+            | Native C++ bindings via `node-gyp`  |
| Browser  | Modern engines  | WebAssembly (pre-built)             |

### Python (`navio-blsct`)

[`pip install navio-blsct`](https://pypi.org/project/navio-blsct/).

Docs: <https://nav-io.github.io/libblsct-bindings/>. Python bindings are generated via SWIG from the same C++ interface; classes and method names track the TypeScript API closely.

Quickstart (illustrative — check the upstream README for the current API):

```python
from blsct import Scalar, Point, BlsctChain, set_chain

set_chain(BlsctChain.Mainnet)
s = Scalar.random()
p = Point.from_scalar(s)
print(s.to_hex(), p.to_hex())
```

Use cases:

-   Backend services (exchange ingest, indexers, analytics).
-   Off-chain proof verification in scientific / audit workflows.
-   Test harnesses and fuzzing rigs around consensus-critical code.

### C# and Rust

Both live in the repository and are built and tested in CI on Linux, macOS and Windows; build them from source (see each `ffi/<lang>/README.md`). `cargo build` builds `libblsct` at the pinned navio-core commit and links it statically; `BLSCT_PREBUILT_DIR` links archives already built for the same pin.

### C, Go (planned)

Status: planned. See upstream README for current state. The C binding ships a stable ABI suitable for FFI into any other language (Ruby, Haskell, Zig, etc.) when it lands.

## Picking a language

| Use case                                         | Recommended binding                        |
| ------------------------------------------------ | ------------------------------------------ |
| Browser wallet                                   | TS (WASM)                                   |
| Node.js backend, CLI tool                        | TS (native)                                 |
| Python data pipeline, Jupyter notebook, scripts   | Python                                     |
| .NET services                                    | C# (from source)                           |
| High-performance native use                      | Rust (from source)                         |
| Cross-language system with heterogeneous clients | TS + Python packages; C eventually         |
