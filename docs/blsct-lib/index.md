# libblsct-bindings

**libblsct-bindings** exposes Navio's confidential-transaction primitives (`libblsct`) to multiple programming languages. It is the umbrella project that delivers `libblsct` as a first-class dependency outside the C++ codebase — so any application stack can build BLSCT transactions, derive keys, verify proofs, and interact with the protocol natively.

-   **Repository**: [nav-io/libblsct-bindings](https://github.com/nav-io/libblsct-bindings)
-   **License**: MIT

## Supported languages

| Language             | Package                                                                                | Runtime                          | Status     |
| -------------------- | -------------------------------------------------------------------------------------- | -------------------------------- | ---------- |
| TypeScript / JavaScript | [`navio-blsct`](https://www.npmjs.com/package/navio-blsct) (npm)                    | Node.js (native C++) + Browser (WASM) | Shipping |
| Python               | [`navio-blsct`](https://pypi.org/project/navio-blsct/) (PyPI)                          | CPython 3.x                      | Shipping   |

## Planned languages

-   C — flat FFI surface for any host language that can dlopen a shared library.
-   Rust — idiomatic Rust wrapper.
-   Go — cgo-based binding.

Track language status in the upstream README: <https://github.com/nav-io/libblsct-bindings>.

## What all bindings expose

Every language surface covers the same core primitives — naming and idioms differ, semantics do not:

-   Curve arithmetic — scalars and $G_1$ points on BLS12-381.
-   Keys — private keys, public keys, double public keys, sub-addresses, HD derivation.
-   Transactions — `CTx`, `CTxIn`/`CTxIns`, `CTxOut`/`CTxOuts`, `CTxId`, `OutPoint`.
-   Privacy primitives — Pedersen commitments, range proofs, amount recovery.
-   Signatures — BLS aggregate signatures and verifications.
-   Network context — `setChain` / `BlsctChain` equivalents.

Each binding is generated from the same underlying SWIG interface (`swig/`) with a language-specific `ffi/<lang>/` wrapper. Bindings stay in lockstep with navio-core via a vendored submodule.

## Bindings by language

### TypeScript / JavaScript (`navio-blsct`)

Documentation in this section describes the TypeScript binding in detail — it is the most feature-complete at the moment and is what [navio-sdk](../sdk/index.md) consumes.

| Page                                              | Topic                                                          |
| ------------------------------------------------- | -------------------------------------------------------------- |
| [Installation](install.md)                        | Node install, browser bundler config, `loadBlsctModule()`      |
| [Primitives](primitives.md)                       | `Scalar`, `Point`, `Signature`, `Script`                       |
| [Keys](keys.md)                                   | `PublicKey`, `PublicKeys`, `DoublePublicKey`, `SubAddress`     |
| [Transactions](transactions.md)                   | `CTx`, `CTxIn`/`CTxIns`, `CTxOut`/`CTxOuts`, `CTxId`, `OutPoint` |
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

### C, Rust, Go (planned)

Status: planned. See upstream README for current state. The C binding ships a stable ABI suitable for FFI into any other language (Ruby, Haskell, Zig, etc.) when it lands.

## Picking a language

| Use case                                         | Recommended binding                        |
| ------------------------------------------------ | ------------------------------------------ |
| Browser wallet                                   | TS (WASM)                                   |
| Node.js backend, CLI tool                        | TS (native)                                 |
| Python data pipeline, Jupyter notebook, scripts   | Python                                     |
| High-performance embedded use                    | (awaiting) C or Rust                       |
| Cross-language system with heterogeneous clients | TS + Python today; C eventually            |
