# Memory model

`navio-blsct` wraps objects that live in native memory (C++ heap in Node.js, WASM heap in browser). This page documents the lifetime rules so you avoid leaks and use-after-free bugs.

## `ManagedObj`

Every class in the library inherits from a `ManagedObj` base that holds a pointer to the native object. In Node.js the pointer is a `Napi::External`; in browser WASM it is a pointer into the wasm heap.

### Node.js

Node's garbage collector finalises the native object when the JS wrapper becomes unreachable. In practice you can treat objects like normal JS values — GC handles cleanup.

**Caveats:**

-   Finalisation runs on a separate thread. For correctness under pathological scripts that create millions of Scalars per second, consider periodically calling `gc()` if `--expose-gc` is enabled, or re-use objects where possible.
-   Objects reference process-global precomputed tables (generator bases, etc.). These tables are initialised once at module load and never freed — expected behaviour.

### Browser (WASM)

The WASM heap does **not** integrate with the browser's JS GC. Every managed object allocates WASM memory that must be freed explicitly.

`navio-blsct` mitigates this with a `FinalizationRegistry` that calls the native destructor when the JS wrapper is collected. But JS GC is non-deterministic — the WASM heap can grow faster than GC catches up.

**For long-running browser wallets:**

```ts
import { Scalar } from 'navio-blsct';

const s = Scalar.random();
// ... use s ...
s.dispose();     // explicit free — avoids waiting for GC
```

All managed objects expose `.dispose()`. Calling it on an already-disposed object is a no-op. After dispose, any method call throws.

### Disposable pattern

A small helper you can paste into your project:

```ts
export async function using<T extends { dispose(): void }>(
    obj: T,
    fn: (o: T) => Promise<any>,
) {
    try { return await fn(obj); }
    finally { obj.dispose(); }
}

// use
await using(Scalar.random(), async (s) => {
    console.log(s.toHex());
});
```

## Clone semantics

Most operations return **new** managed objects rather than mutating in place:

```ts
const a = Scalar.fromBigInt(2n);
const b = Scalar.fromBigInt(3n);
const c = a.add(b);          // c is a new Scalar; a and b are unchanged
```

Exceptions are clearly flagged in method names (`mutAdd`, `reset`) — these mutate in place to avoid allocation in hot loops.

## Performance tips

-   **Hot loops in browser** — pre-allocate and reuse scratch scalars via `mut*` methods where available.
-   **Aggregation** — use batched APIs (`PublicKeys.verifyAggregate`, `Signature.aggregate`) rather than looping.
-   **Scalars from hex** — cache parsed scalars when the same hex appears repeatedly.
-   **Point scalar-mul** uses Pippenger when supplied with a vector; prefer `Point.multiScalarMul([...])` over a loop of `p.mul(s)`.

## Thread safety

-   **Node native** — each `Scalar`/`Point`/`etc.` is not thread-safe for mutation, but immutable operations are safe to call concurrently (the underlying libblsct is thread-safe for read-only ops).
-   **Browser WASM** — single-threaded by default. Web Workers with `SharedArrayBuffer` are supported but managed objects do *not* cross worker boundaries without explicit serialisation (`toBytes` / `fromBytes`).
