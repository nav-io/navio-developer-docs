---
hide:
    - navigation
    - toc
---

# Navio Technical Knowledge Base

**Navio** is a Bitcoin Core fork with [BLSCT](concepts/blsct-model.md) confidential transactions at the base layer. Amounts and parties are hidden for every shielded output, while the chain remains publicly verifiable through BLS12-381 range proofs and Pedersen commitments. Its consensus algorithm is **Proof-of-Private-Stake (PoPS)** — stake weight without disclosing balances or controlled outputs.

This knowledge base documents the entire Navio surface — protocol, node operation, RPC, BLSCT internals, SDK, explorer, and integration guides:

<div class="grid cards" markdown>

-   :material-book-open-variant: **[Concepts](concepts/index.md)**

    The protocol from the top down. BLSCT privacy model, outpoint semantics, consensus & supply, networks, wallet formats.

-   :material-server: **[Node Operator](node/index.md)**

    Build, run, and operate `naviod`. Configuration reference, staking, ElectrumX, pruning, backup, security hardening.

-   :material-console-line: **[RPC Reference](rpc/index.md)**

    Every JSON-RPC command, grouped by category. Full BLSCT RPC surface — tokens, NFTs, raw transactions, balance proofs.

-   :material-shield-lock-outline: **[BLSCT Protocol](blsct/index.md)**

    BLS12-381, double public keys, output construction, view tags, amount recovery, range proofs, signatures, on-chain format.

-   :material-language-typescript: **[SDK — navio-sdk](sdk/index.md)**

    TypeScript SDK for wallet management, sync, and transaction construction. Runs in Node.js and browsers.

-   :material-key-chain-variant: **[libblsct-bindings](blsct-lib/index.md)**

    Multi-language bindings for `libblsct` — TypeScript (native + WASM) and Python shipping; C, Rust, Go planned. Curve primitives, keys, range proofs, CTx.

-   :material-magnify-scan: **[Block Explorer — navio-blocks](explorer/index.md)**

    Full-stack block explorer. Indexer, REST API, React frontend. Self-host guide + complete API reference.

-   :material-school-outline: **[Guides](guides/index.md)**

    End-to-end tutorials: build a wallet, mint NFTs, run a staking VPS, atomic swaps, exchange integration.

</div>

---

## Quick links

-   **New to Navio?** Start with [the protocol overview](concepts/overview.md).
-   **Running a node?** Follow [the install guide](node/install.md).
-   **Integrating?** Use the [SDK quickstart](sdk/quickstart.md) or call [RPC directly](rpc/index.md).
-   **Building privately-aware explorers or analytics?** Read the [outpoint model](concepts/outpoint.md) and [BLSCT deep dive](blsct/index.md).

---

## Project repositories

| Repository                                                             | Purpose                                                                |
| ---------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [`nav-io/navio-core`](https://github.com/nav-io/navio-core)            | `naviod`, `navio-cli`, `navio-staker`, `navio-wallet` — the reference C++ implementation. |
| [`nav-io/navio-sdk`](https://github.com/nav-io/navio-sdk)              | TypeScript SDK for wallets, sync, and transactions.                    |
| [`nav-io/libblsct-bindings`](https://github.com/nav-io/libblsct-bindings) | Multi-language bindings for `libblsct` — TypeScript (native + WASM), Python. C/Rust/Go planned. |
| [`nav-io/navio-blocks`](https://github.com/nav-io/navio-blocks)        | Block explorer (indexer + API + frontend).                             |
| [`nav-io/navio-developer-docs`](https://github.com/nav-io/navio-developer-docs) | This site. Contributions welcome via PR.                               |

---

!!! info "About this documentation"
    API references for the SDK and BLSCT library are **automatically generated nightly** from the upstream repositories using TypeDoc. RPC documentation is generated from `naviod -help` and source headers. The explorer's REST API is generated from its OpenAPI (Swagger) spec. If you spot an outdated handwritten page, [open an issue](https://github.com/nav-io/navio-developer-docs/issues) or a PR.
