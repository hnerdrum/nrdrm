# nrdrm

Apps in this repo are independent. They share local Postgres via [`docker-databases.yml`](docker-databases.yml).

## Setup

1. Install [mise](https://mise.jdx.dev/).
2. From the repo root: `mise install`.
3. Haskell apps also need [Stack](https://docs.haskellstack.org/). GHC is not installed by mise; Stack pulls it from `server/recipes/stack.yaml`.
4. Start databases:

```bash
docker compose -f docker-databases.yml up -d
```

| Host port | Database   | Used by                              |
| --------- | ---------- | ------------------------------------ |
| 5432      | `recipes`  | [`server/recipes`](server/recipes)   |
| 5433      | `identity` | [`server/identity`](server/identity) |
| 5434      | `uno`      | [`server/uno`](server/uno)           |

Copy each app’s `.env.example` to `.env` (or `.env.local` for Next.js) before running it.

## Apps

Each app README uses the same verbs: **run**, **test**, **build**, **migrate**.

### Backends

- [`server/recipes`](server/recipes) — Haskell recipe API
- [`server/identity`](server/identity) — Rust auth API
- [`server/gateway`](server/gateway) — Gleam reverse proxy
- [`server/uno`](server/uno) — Go Uno API (local only)

Shared Haskell libraries: [`server/orm`](server/orm), [`server/orm-codegen`](server/orm-codegen).

### Frontends

- [`web/recipes`](web/recipes) — Next.js, talks to the gateway
- [`web/uno`](web/uno) — SvelteKit, talks to the Uno API directly
- [`web/home`](web/home) — Astro landing page
- [`web/wedding`](web/wedding) — Astro wedding site

### Jobs

- [`cron/delete-container-images`](cron/delete-container-images) — Scaleway registry cleanup

## Recipes stack

The only multi-service path used daily. Start databases first, then one process per terminal:

```bash
# server/identity — diesel migration run, then cargo run   (:8081)
# server/recipes  — make run                               (:8000)
# server/gateway  — gleam run                              (:8080)
# web/recipes     — npm run dev                            (:3000 → gateway)
```
