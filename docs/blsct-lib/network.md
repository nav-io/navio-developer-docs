# Network configuration

BLSCT primitives use a process-global *chain context* that affects:

-   Bech32m HRP (`nav` / `tnav` / `tnavrt`).
-   Token-id serialisation padding.
-   Some consensus-specific constants (activation heights, etc.).

## Setting the chain

```ts
import { setChain, getChain, BlsctChain } from 'navio-blsct';

setChain(BlsctChain.Mainnet);   // default
setChain(BlsctChain.Testnet);
setChain(BlsctChain.Signet);
setChain(BlsctChain.Regtest);

getChain();                     // current BlsctChain
```

## When the SDK does it

The [SDK](../sdk/index.md) calls `setChain` automatically based on the `network` field in `NavioClientConfig`. If you use `navio-sdk`, you rarely need to call these directly. If you use `navio-blsct` standalone, **call `setChain` before any other primitive** — not calling it defaults to Mainnet.

## Multiple networks in one process

Chain context is process-global. Running two SDK clients on different networks in the same process will cause HRP/metadata conflicts. For dual-network wallets:

-   Separate worker threads / processes per network — recommended.
-   Or, serialise operations and flip the chain before each call — fragile, not supported.

## `BlsctChain` enum

```ts
enum BlsctChain {
    Mainnet = 0,
    Testnet = 1,
    Signet  = 2,
    Regtest = 3,
}
```

The numeric values are library-internal — do not persist them across upgrades.
