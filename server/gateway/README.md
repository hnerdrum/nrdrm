# gateway

Gleam reverse proxy. No database. Routing lives in [`gateway.json`](gateway.json), the same file in every environment.

## Run

```bash
just gateway run       # env bootstrap, then gleam run
```

Listens on `PORT`. CORS: `ALLOWED_ORIGINS`. Upstream URLs come from `RECIPES_URL`, `IDENTITY_URL` and `AGENTS_URL` (locally `:8000`, `:8081` and `:8090`, see `.env.example`). Every one of these must be set. If your `.env` predates them, copy the new lines from `.env.example`.

## Config

`gateway.json` has three parts:

- `upstreams`: the backends, each with a `name`, a `url` and a `timeout_ms`. A `url` can reference environment variables as `${NAME}`.
- `routes`: requests for `/<prefix>/...` go to the route's `upstream`. Only headers in `request_headers` reach the upstream, and only headers in `response_headers` (plus `content-type`) come back.
- `identity_upstream`: the upstream the gateway asks to check sessions and bearer tokens.

Each route lists `rules`. The first rule whose `path` and `methods` match the request decides its `auth`:

- `"public"`: forwarded as is.
- `"session"`: identity must accept the caller's session cookie.
- `{"bearer": {"audience": "agents"}}`: identity must introspect the `Authorization: Bearer` token as active for that audience. The gateway then sends the token's client name to the upstream as `x-nrdrm-client`, and does not send the token itself.

A request that matches no rule gets a 404, including a listed path called with a method its rules don't list. Only what `gateway.json` lists is reachable, so a new upstream endpoint needs a rule before clients can call it. Identity's `validate-token` and `oauth/introspect` are deliberately unlisted: only the gateway calls them, and it calls identity directly.

A rule's `path` is matched segment by segment against the path after `/<prefix>`: a literal segment matches itself, `*` matches exactly one segment, and `**` (last segment only) matches any remaining segments, including none.

The gateway checks the whole file and its environment variables when it boots. If anything is wrong, it lists every problem and exits.

## Test

```bash
just gateway test
```

## Build

```bash
just gateway build
```

## Migrate

Not applicable.
