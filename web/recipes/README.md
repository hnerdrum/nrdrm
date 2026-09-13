# recipes web

Next.js app. Talks to the [gateway](../../server/gateway) (`NEXT_PUBLIC_SERVER_URL`), not to backends directly.

## Run

Start the [recipes stack](../../README.md#recipes-stack) backends first, then:

```bash
cd web/recipes
cp .env.example .env.local
npm install
npm run dev
```

Opens on http://localhost:3000.

## Test

No automated tests. Lint:

```bash
npm run lint
```

## Build

```bash
npm run build
```

## Migrate

Not applicable.
