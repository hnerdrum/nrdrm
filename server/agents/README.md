# agents

Effect HTTP service for the agent runner. Runs are stored in Postgres database `agents` on port `5436` (`just db up`).

## Run

```bash
just agents run
```

Listens on `PORT` (8090 in the example). `GET /health` returns `{ "status": "ok" }` and does not check a caller key. The process requires `AGENTS_API_KEY`, `SCALEWAY_API_KEY`, `DATABASE_URL`, `GITHUB_APP_ID`, `GITHUB_WEBHOOK_SECRET`, and `GITHUB_PRIVATE_KEY`, and does not start when any of them is missing or empty. `GITHUB_PRIVATE_KEY` is the GitHub App private key. Newlines in that value are written as `\n`.

`POST /complete` and `POST /runs` require `Authorization: Bearer <AGENTS_API_KEY>`. A missing or wrong key returns 401 and does not call a model.

`POST /complete` takes `{ "model", "prompt" }`. `model` is `scaleway` or `openai`. The response is `{ "text", "provider", "modelId" }`. `scaleway` is `mistral-small-3.2-24b-instruct-2506` at `https://api.scaleway.ai/v1`. `openai` (`gpt-4.1-mini`) is available only when `OPENAI_API_KEY` is set.

`POST /runs` takes `{ "skill", "input", "model" }`. `model` is `scaleway` or `openai`. It loads `skills/<skill>.md` as the system prompt and runs that skill's tools. For every skill except `review-pr`, the response is `{ "id", "text", "skill", "actor", "provider", "modelId" }`. `actor` is `agent:<skill>`. A finished run is stored with that id, the model id, token counts, and start and finish times. An unknown skill returns 404 and does not call a model. Input that contains an email, a phone number, or an 11-digit national id returns 400 `{ "error": "input refused", "id" }` and does not call a model. That row is stored with status `refused`, the requested model name, and zero tokens. `skills/ping.md` has no tools and answers in one line.

`skills/review-pr.md` reviews a unified diff. The response is `{ "id", "summary", "comments", "skill", "actor", "provider", "modelId" }`. Each comment is `{ "path", "side", "line", "body" }`. `side` is `LEFT` or `RIGHT`. Comments whose path, side, and line are not an added or removed line in the diff are dropped, and at most 50 comments are returned. On a rename, `LEFT` uses the old path and `RIGHT` uses the new path. A `body` may contain a GitHub suggestion block. Input longer than 100000 characters returns 400 `{ "error": "diff too large", "id" }` and does not call a model. That row is stored with status `too-large`, the requested model name, and zero tokens. A model reply that is not the review object is stored with status `failed` and returns 502.

`POST /webhooks/github` does not check the caller key. It checks `X-Hub-Signature-256` and returns `{ "ok": true }`. A missing or wrong signature returns 401 and does not start a review. A `pull_request` delivery for `hnerdrum/nrdrm` whose action is `opened` on a pull request that is not a draft, or `ready_for_review`, runs `review-pr` after that response and posts one review on the pull request head. The summary is the review body. Inline comments are the ones `review-pr` kept. A repeated `X-GitHub-Delivery` does nothing. A refused or too-large diff posts `Review skipped.` and does not quote the diff. A push does not start a review.

A new comment on a pull request in `hnerdrum/nrdrm` that mentions `@ragnhild-review`, from someone who can write to the repository, is read after that response. The model chooses the action. A request for a review of the pull request runs `review-pr` and posts one review. Any other request is answered in a new comment, using the diff when it fits. A comment from the app is ignored. A refused comment is answered with `I can't answer that.` and does not quote the comment.

`GET /runs/:id` requires the same caller key and returns that row: `{ "id", "skill", "actor", "status", "modelId", "inputTokens", "outputTokens", "startedAt", "finishedAt" }`. A missing id returns 404.

```sh
curl -s localhost:8090/complete \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"model":"scaleway","prompt":"Reply with one word: pong"}'

curl -s localhost:8090/runs \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"skill":"ping","input":"Say pong","model":"scaleway"}'

curl -s localhost:8090/runs \
  -H "authorization: Bearer $AGENTS_API_KEY" \
  -H 'content-type: application/json' \
  -d '{"skill":"review-pr","model":"scaleway","input":"diff --git a/src/hello.ts b/src/hello.ts\n--- a/src/hello.ts\n+++ b/src/hello.ts\n@@ -1 +1 @@\n-export const hello = \"hi\"\n+export const hello = \"hello\"\n"}'
```

## Test

No automated tests yet.

## Build

```bash
just agents build
```

## Migrate

```bash
just agents migrate
```

The server applies the SQL in `drizzle/` when it starts, including the deployed container. `just agents migrate` applies those same files without starting the server, and `just agents run` does that first. Local commands read `DATABASE_URL` from `.env`. The deployed container reads it from its environment.
