# uno web

SvelteKit app. Talks to [`server/uno`](../../server/uno) directly (`PUBLIC_SERVER_URL`), not through the gateway.

## Run

Start databases and the Uno API first (`just uno run`), then:

```bash
cp .env.example .env
npm install
just web-uno run       # or: just web-uno dev
```

Vite default port is 5173.

## Test

No automated tests. Typecheck / lint:

```bash
just web-uno test      # svelte-check
npm run lint
```

## Build

```bash
just web-uno build
```

## Migrate

Not applicable.
