# API reference

!!! info "Auto-generated"
    This section is regenerated nightly from the [navio-blsct](https://github.com/nav-io/navio-blsct) source by:

    ```
    typedoc --plugin typedoc-plugin-markdown --out docs/blsct-lib/api
    ```

    Until the next build, run `npm run docs` in the [navio-blsct](https://github.com/nav-io/navio-blsct) repo to generate the current reference locally.

## Structure

After the nightly build this directory contains:

-   `classes/` — `Scalar`, `Point`, `Signature`, `Script`, `PublicKey`, `PublicKeys`, `DoublePublicKey`, `SubAddress`, `SubAddrId`, `CTx`, `CTxIn`, `CTxIns`, `CTxOut`, `CTxOuts`, `CTxId`, `OutPoint`, `RangeProof`, `AmountRecoveryReq`, `AmountRecoveryRes`, `TokenId`, `TokenInfo`, `HashId`, `ManagedObj`.
-   `enumerations/` — `BlsctChain`.
-   `functions/` — `setChain`, `getChain`, `loadBlsctModule`, `setWasmBasePath`.
-   `type-aliases/` — ancillary types.
-   `variables/` — runtime constants.

## Exports

```ts
// Core primitives
export { Scalar, Point, Signature, Script } from './primitives';

// Keys
export { PublicKey, PublicKeys, DoublePublicKey, SubAddress, SubAddrId } from './keys';

// Transactions
export { CTx, CTxIn, CTxIns, CTxOut, CTxOuts, CTxOutBLSCTData, CTxId, OutPoint } from './ctx';

// Privacy
export { RangeProof, AmountRecoveryReq, AmountRecoveryRes, TokenId, TokenInfo, HashId } from './privacy';

// Network
export { setChain, getChain, BlsctChain } from './chain';

// WASM (browser)
export { loadBlsctModule, setWasmBasePath } from './wasm';

// Base class
export { ManagedObj } from './managed';

// Utilities
export { encodeStringMap, decodeStringMap } from './stringMapUtil';
```
