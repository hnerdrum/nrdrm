# gateway

Gleam reverse proxy. No database. Routing lives in [`gateway.json`](gateway.json), the same file in every environment.

## Run

```bash
just gateway run       # env bootstrap, then gleam run
```

Listens on `PORT`. CORS: `ALLOWED_ORIGINS`. Upstream URLs come from `RECIPES_URL`, `IDENTITY_URL`, `AGENTS_URL` and `TRAINING_URL` (locally `:8000`, `:8081`, `:8090` and `:8082`, see `.env.example`). Every one of these must be set. If your `.env` predates them, copy the new lines from `.env.example`.

## Config

`gateway.json` has three parts:

- `upstreams`: the backends, each with a `name`, a `url` and a `timeout_ms`. A `url` can reference environment variables as `${NAME}`.
- `routes`: requests for `/<prefix>/...` go to the route's `upstream`. Only headers in `request_headers` reach the upstream, and only headers in `response_headers` (plus `content-type`) come back. Headers the gateway sets itself (`x-request-id` and `x-nrdrm-*`) always reach the upstream and need no `request_headers` entry. The prefix `_gateway` is reserved.
- `identity_upstream`: the upstream the gateway asks to check sessions and bearer tokens.

Each route lists `rules`. The first rule whose `path` and `methods` match the request decides its `auth`:

- `"public"`: forwarded as is.
- `"session"`: identity must accept the caller's session cookie. Cookies identity sets while checking it, such as a refreshed session, are returned to the caller.
- `{"bearer": {"audience": "agents"}}`: identity must introspect the `Authorization: Bearer` token as active for that audience. The gateway then sends the token's client name to the upstream as `x-nrdrm-client`, and does not send the token itself.

On the recipes routes, creates and reads are public. Updates and deletes need a session. The recipes server does not check auth itself.

A request that matches no rule gets a 404, including a listed path called with a method its rules don't list. Only what `gateway.json` lists is reachable, so a new upstream endpoint needs a rule before clients can call it. Identity's `validate-token` and `oauth/introspect` are deliberately unlisted: only the gateway calls them, and it calls identity directly.

A rule's `path` is matched segment by segment against the path after `/<prefix>`: a literal segment matches itself, `*` matches exactly one segment, and `**` (last segment only) matches any remaining segments, including none.

The gateway checks the whole file and its environment variables when it boots. If anything is wrong, it lists every problem and exits.

## Request ids

Every request gets an id. The gateway keeps the caller's `x-request-id` if it is 1–64 characters of `[A-Za-z0-9._-]`, and generates a new one otherwise. It returns the id as `x-request-id` on every response, including errors and CORS preflights, and sends it to the upstream and to identity on every call it makes for that request.

## Logs

Logs go to stdout as one JSON object per line, with `time`, `level`, `msg` and, while a request is being handled, its `request_id`. Each request writes one access-log line with `"msg":"request"` plus `method`, `path` (without the query string), `route` (the prefix, or empty), `upstream` (or empty), `status` and `duration_ms`.

```json
{
  "time": "2026-10-26T20:23:00.073049Z",
  "level": "info",
  "msg": "request",
  "request_id": "smoke-2",
  "method": "POST",
  "path": "/agents/webhooks/github",
  "route": "agents",
  "upstream": "agents",
  "status": 502,
  "duration_ms": 79
}
```

## Gateway endpoints

- `GET /_gateway/livez`: `200 {"status":"ok"}` while the process is running. It calls no upstream.
- `GET /_gateway/status`: the gateway's `boot_time` and `api_version`, plus one entry per upstream from `GET <upstream>/health`. All upstreams are checked at once, with a 2-second timeout each. An entry has `up` (any 2xx), `status` (`null` if the upstream couldn't be reached in time), `duration_ms`, and `boot_time` and `api_version` when the upstream returns them. The endpoint always answers 200; read `up` for the result.

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
