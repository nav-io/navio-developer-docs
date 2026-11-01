# API reference

!!! info "Auto-generated"
    This section is regenerated nightly from the TypeScript binding in [libblsct-bindings](https://github.com/nav-io/libblsct-bindings/tree/main/ffi/ts) (`@nav-io/navio-blsct`) by `scripts/fetch-blsct-docs.sh`:

    ```
    typedoc --plugin typedoc-plugin-markdown --out docs/blsct-lib/api
    ```

    Until the next build, run `npm run docs` in `ffi/ts` of [libblsct-bindings](https://github.com/nav-io/libblsct-bindings) to generate the current reference locally.

## Structure

After the nightly build this directory contains:

-   `classes/` — `Scalar`, `Point`, `Signature`, `Script`, `PublicKey`, `PublicKeys`, `DoublePublicKey`, `SubAddress`, `SubAddrId`, `CTx`, `CTxIn`, `CTxIns`, `CTxOut`, `CTxOuts`, `CTxId`, `OutPoint`, `RangeProof`, `AmountRecoveryReq`, `AmountRecoveryRes`, `TokenId`, `TokenInfo`, `HashId`, `ManagedObj`.
-   `enumerations/` — `BlsctChain`.
-   `functions/` — `setChain`, `getChain`, `loadBlsctModule`, `parseStakeDelegationOwnerInfo`, `parseDataPredicateData`.
-   `type-aliases/` — ancillary types.
-   `variables/` — runtime constants.

## Exports

Simplified map of the main entry points (current release: 1.3.0). The package re-exports every module under `src/`, including `TxIn`, `TxOut`, `UnsignedOutput`, `UnsignedTransaction`, `SubAddr`, `SubAddrId` and the token-predicate helpers.

```ts
// Core primitives
export { Scalar, Point, Signature, Script } from './primitives';

// Keys
export { PublicKey, PublicKeys, DoublePublicKey, SubAddress, SubAddrId } from './keys';

// Transactions
export { CTx, CTxIn, CTxIns, CTxOut, CTxOuts, CTxOutBLSCTData, CTxId, OutPoint } from './ctx';

// Privacy
export { RangeProof, AmountRecoveryReq, AmountRecoveryRes, TokenId, TokenInfo, HashId } from './privacy';

// Cold staking (1.3.0+)
export {
    buildStakeDelegationDataHex, isStakeDelegationDataHex,
    parseStakeDelegationOwnerInfo, type StakeDelegationOwnerInfo,
} from './stakeDelegation';
export { parseDataPredicateData } from './tokenPredicate';

// Network
export { setChain, getChain, BlsctChain } from './chain';

// WASM (browser entry, '@nav-io/navio-blsct/browser')
export { loadBlsctModule, isModuleLoaded, type LoadBlsctModuleOptions } from './bindings/wasm';

// Base class
export { ManagedObj } from './managed';

// Utilities
export { encodeStringMap, decodeStringMap } from './stringMapUtil';
```
