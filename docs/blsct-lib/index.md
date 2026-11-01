# libblsct-bindings

**libblsct-bindings** exposes Navio's confidential-transaction primitives (`libblsct`) to multiple programming languages. It is the umbrella project that delivers `libblsct` as a first-class dependency outside the C++ codebase — so any application stack can build BLSCT transactions, derive keys, verify proofs, and interact with the protocol natively.

-   **Repository**: [nav-io/libblsct-bindings](https://github.com/nav-io/libblsct-bindings)
-   **License**: MIT

## Supported languages

| Language             | Package                                                                                | Latest   | Runtime                          | Status     |
| -------------------- | -------------------------------------------------------------------------------------- | -------- | -------------------------------- | ---------- |
| TypeScript / JavaScript | [`@nav-io/navio-blsct`](https://www.npmjs.com/package/@nav-io/navio-blsct) (npm)    | 1.3.0 (2026-10-16) | Node.js (native C++) + Browser (WASM) | Shipping |
| Python               | [`navio-blsct`](https://pypi.org/project/navio-blsct/) (PyPI)                          | 0.0.40 (2026-10-25) | CPython 3.x                 | Shipping   |
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

In the repository, the Rust binding also wraps the stake-delegation C API and reads DATA predicate payloads and full `scriptPubKey`s, and the C# binding is tested end to end for cold staking.

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
