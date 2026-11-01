# Installation

```bash
npm install @nav-io/navio-blsct
```

!!! note "Package name"
    The TypeScript binding is published as **`@nav-io/navio-blsct`** (current: 1.3.0). The unscoped `navio-blsct` npm package stopped at 1.1.15 and is not updated; navio-sdk depends on the scoped package. Since 1.2.0 the binding is built against navio-core's vendored supranational/blst backend.

## Node.js

Requirements:

-   Node.js ≥ 18 (latest LTS recommended).
-   `g++`, `make`, `swig`, `autoconf`, `automake`, `libtool`, `pkg-config` — the package builds native C++ libraries from source during install. Expect a few minutes on first install.
-   Windows: Visual Studio 2022 (or its Build Tools) with the "Desktop development with C++" workload, CMake and git.

The native library is built from the navio-core commit pinned in the package's `navio-core.sha`.

```ts
import { Scalar, Point, BlsctChain, setChain } from '@nav-io/navio-blsct';

setChain(BlsctChain.Mainnet);

const s = Scalar.random();
console.log(s.toHex());
```

## Browser / WASM

The npm package ships pre-built WASM — **no build step required** on installation. But you must initialise the WASM module before calling any primitive:

```ts
import {
    loadBlsctModule,
    Scalar, Point,
    BlsctChain, setChain,
} from '@nav-io/navio-blsct/browser';

await loadBlsctModule();

setChain(BlsctChain.Mainnet);
const s = Scalar.random();
```

### Bundler config

If your bundler respects the `browser` entry in `package.json` automatically, you can use the plain import:

```ts
import { loadBlsctModule, Scalar } from '@nav-io/navio-blsct';
await loadBlsctModule();
```

Vite, Webpack 5, and esbuild all respect the field out of the box. For older toolchains, use the explicit `/browser` subpath.

### Serving WASM files

The WASM loader and binary ship in the package's `wasm/` directory (`@nav-io/navio-blsct/wasm/blsct.js`, `…/blsct.wasm`) and are resolved relative to the loader by default. If your host restricts asset paths, copy them into your static assets and pass the location, or the binary itself, to `loadBlsctModule()`:

```ts
import { loadBlsctModule } from '@nav-io/navio-blsct/browser';

await loadBlsctModule({ wasmPath: '/assets/blsct/blsct.js' });
// or: await loadBlsctModule({ wasmBinary: await (await fetch('/assets/blsct.wasm')).arrayBuffer() });
```

## Tree-shaking

The library is ESM-first. All exports are named. A typical Vite / Rollup build retains only the classes you import — a browser wallet that only uses `Scalar`, `SubAddress`, and `RangeProof` should keep the bundle well under 500 KB (plus the WASM binary).

## TypeScript

Full `.d.ts` coverage ships with the package. No separate `@types` package needed.

```ts
// tsconfig essentials
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true
  }
}
```
