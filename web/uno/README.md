# uno web

SvelteKit app. Talks to [`server/uno`](../../server/uno) directly (`PUBLIC_SERVER_URL`), not through the gateway.

## Run

Start databases and the Uno API first (`go run .` in `server/uno`), then:

```bash
cd web/uno
cp .env.example .env
npm install
npm run dev
```

Vite default port is 5173.

## Test

No automated tests. Typecheck / lint:

```bash
npm run check
npm run lint
```

## Build

```bash
npm run build
```

## Migrate

Not applicable.
