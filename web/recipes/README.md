# recipes web

Next.js app. Talks to the [gateway](../../server/gateway) (`NEXT_PUBLIC_SERVER_URL`), not to backends directly.

## Run

Start the [recipes stack](../../README.md#recipes-stack) backends first, then:

```bash
npm install
just web-recipes run   # env bootstrap to .env.local, then npm run dev
```

Opens on http://localhost:3000.

## Test

No automated tests. Lint:

```bash
just web-recipes test
```

## Build

```bash
just web-recipes build
```

## Migrate

Not applicable.
