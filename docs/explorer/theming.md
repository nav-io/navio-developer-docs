# Customising the frontend

The explorer frontend is a React 19 + Vite + Tailwind app. Layout in `packages/frontend/src/`:

```
src/
├── App.tsx
├── main.tsx
├── api.ts              centralised API client
├── utils.ts
├── layout/             header, footer, shell
├── pages/              one per route
├── components/         reusable pieces
├── hooks/              custom hooks
└── index.css           Tailwind entry
```

## Design system

The default theme uses a cyberpunk palette. Tailwind config tokens (`tailwind.config.js`):

-   **`navy-900`** `#0a0e27` — page background
-   **`navy-800`** `#10152e` — cards
-   **`cyan-400`** `#00d4ff` — primary accent (links, borders, glows)
-   **`purple-500`** `#7b5cff` — secondary accent (gradients)
-   **`pink-400`** `#ff5cf0` — tertiary accent
-   Mono font: JetBrains Mono
-   Sans: Inter

Badges used throughout:

-   `<PrivacyBadge kind="blsct" />` — shown on confidential outputs.
-   `<PrivacyBadge kind="transparent" />` — shown on value-visible outputs.
-   `<OutputTypeBadge>` — coinbase / coinstake / standard.

## Adding a page

1.  Create `packages/frontend/src/pages/MyPage.tsx`.
2.  Add a route in `App.tsx` under the existing `Routes`.
3.  Add a link in `layout/Header.tsx` or wherever appropriate.
4.  Fetch data using the `api.ts` helper for auth + base-URL handling.

Example:

```tsx
// src/pages/MyPage.tsx
import { useEffect, useState } from 'react';
import { GlowCard, Loader } from '../components';
import { api } from '../api';

export default function MyPage() {
    const [data, setData] = useState<any>(null);
    useEffect(() => {
        api.get('/api/stats').then(setData);
    }, []);

    if (!data) return <Loader />;
    return (
        <GlowCard title="Network stats">
            <pre>{JSON.stringify(data, null, 2)}</pre>
        </GlowCard>
    );
}
```

## Adding an API endpoint

1.  Create `packages/api/src/routes/myroute.ts` exporting a Fastify plugin.
2.  Add the route declaration with `fastify.get(…, { schema: { response: {…} } })` — the Swagger doc generates from this schema.
3.  Register it in `packages/api/src/index.ts`.

```ts
// packages/api/src/routes/myroute.ts
import { FastifyPluginAsync } from 'fastify';

const myroute: FastifyPluginAsync = async (f) => {
    f.get('/myroute', {
        schema: {
            response: {
                200: { type: 'object', properties: { hello: { type: 'string' } } },
            },
        },
    }, async () => ({ hello: 'world' }));
};

export default myroute;
```

```ts
// packages/api/src/index.ts
import myroute from './routes/myroute.js';
// ...
await fastify.register(myroute, { prefix: '/api' });
```

## Replacing the palette

Edit `tailwind.config.js` and the tokens cascade through every component:

```js
// tailwind.config.js
export default {
    theme: {
        extend: {
            colors: {
                navy: { 900: '#0a0e27', 800: '#10152e' },
                accent: { 400: '#00d4ff' },
            },
        },
    },
};
```

Swap the hex values for your branding. For a light-mode-first design, also set `@layer base` rules in `index.css` to flip the default.

## Localisation

Not implemented by default. To add i18n, introduce `react-i18next`, wrap text in `t('…')` calls, and ship per-locale JSON bundles from `packages/frontend/src/locales/`. The API is already locale-agnostic (returns ISO timestamps and numeric values; formatting happens in the frontend).
