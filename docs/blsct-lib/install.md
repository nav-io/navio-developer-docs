# Installation

```bash
npm install navio-blsct
```

## Node.js

Requirements:

-   Node.js ≥ 18 (latest LTS recommended).
-   `g++`, `make`, `cmake`, `swig`, `pkg-config` — the package builds native C++ libraries from source during install. Expect a few minutes on first install.

```ts
import { Scalar, Point, BlsctChain, setChain } from 'navio-blsct';

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
} from 'navio-blsct/browser';

await loadBlsctModule();

setChain(BlsctChain.Mainnet);
const s = Scalar.random();
```

### Bundler config

If your bundler respects the `browser` entry in `package.json` automatically, you can use the plain import:

```ts
import { loadBlsctModule, Scalar } from 'navio-blsct';
await loadBlsctModule();
```

Vite, Webpack 5, and esbuild all respect the field out of the box. For older toolchains, use the explicit `/browser` subpath.

### Serving WASM files

The WASM binary is loaded at runtime from the package's `dist/browser/` directory. If your host restricts asset paths, copy `node_modules/navio-blsct/dist/browser/*.wasm` into your static assets and set the base path before `loadBlsctModule()`:

```ts
import { setWasmBasePath, loadBlsctModule } from 'navio-blsct';
setWasmBasePath('/assets/blsct');
await loadBlsctModule();
```

## Tree-shaking

The library is ESM-first. All exports are named. A typical Vite / Rollup build retains only the classes you import — a browser wallet that only uses `Scalar`, `SubAddress`, and `RangeProof` should keep the bundle well under 500 KB (plus the WASM binary).

## TypeScript

Full `.d.ts` coverage ships with the package. No `@types/navio-blsct` needed.

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
