import {
  Headers,
  HttpServerRequest,
  HttpServerResponse,
} from "@effect/platform";
import { createHmac, createSign, timingSafeEqual } from "node:crypto";
import { Effect, Option, Redacted, Schema } from "effect";
import { config } from "./config.js";
import { Database } from "./database.js";
import { diffTooLarge } from "./review.js";
import { runMention, runMentionRoute, runReview } from "./runs.js";
import { githubDeliveries } from "./schema.js";
import { jsonError } from "./utils.js";

const repository = "hnerdrum/nrdrm";
const appSlug = "ragnhild-review";
const skipped = "Review skipped.";
const cannotAnswer = "I can't answer that.";
const failedAnswer = "I couldn't answer that.";
const api = "https://api.github.com";
const writers = new Set(["OWNER", "MEMBER", "COLLABORATOR"]);

const mentionExpression = (flags: string) =>
  new RegExp(`@${appSlug}\\b`, flags);

const Webhook = Schema.Struct({
  action: Schema.optional(Schema.String),
  installation: Schema.optional(
    Schema.Struct({
      id: Schema.Number.pipe(Schema.int(), Schema.positive()),
    }),
  ),
  repository: Schema.optional(
    Schema.Struct({
      full_name: Schema.String,
    }),
  ),
  pull_request: Schema.optional(
    Schema.Struct({
      number: Schema.Number.pipe(Schema.int(), Schema.positive()),
      draft: Schema.optional(Schema.Boolean),
    }),
  ),
  issue: Schema.optional(
    Schema.Struct({
      number: Schema.Number.pipe(Schema.int(), Schema.positive()),
      title: Schema.optional(Schema.String),
      body: Schema.optional(Schema.NullOr(Schema.String)),
      pull_request: Schema.optional(Schema.Struct({})),
    }),
  ),
  comment: Schema.optional(
    Schema.Struct({
      body: Schema.String,
      author_association: Schema.optional(Schema.String),
      user: Schema.optional(
        Schema.Struct({
          type: Schema.optional(Schema.String),
        }),
      ),
    }),
  ),
});

const Token = Schema.Struct({
  token: Schema.NonEmptyString,
});

const Pull = Schema.Struct({
  head: Schema.Struct({
    sha: Schema.NonEmptyString,
  }),
});

type GithubConfig = {
  readonly appId: string;
  readonly webhookSecret: Redacted.Redacted;
  readonly privateKey: Redacted.Redacted;
};

type ReviewTarget = {
  readonly installationId: number;
  readonly number: number;
};

type MentionTarget = ReviewTarget & {
  readonly comment: string;
  readonly title: string;
  readonly issueBody: string;
};

const MentionAction = Schema.Struct({
  action: Schema.Literal("review", "reply"),
});

type GithubFailed = { kind: "GithubFailed"; status: number };

type PostedComment = {
  readonly path: string;
  readonly body: string;
  readonly line: number;
  readonly side: "LEFT" | "RIGHT";
};

const ok = () => HttpServerResponse.json({ ok: true }).pipe(Effect.orDie);

const header = (headers: Headers.Headers, name: string) =>
  Option.getOrUndefined(Headers.get(headers, name));

const validSignature = (
  secret: string,
  body: Buffer,
  signature: string | undefined,
) => {
  if (signature === undefined || !signature.startsWith("sha256=")) {
    return false;
  }
  const hex = signature.slice("sha256=".length);
  if (hex.length === 0 || hex.length % 2 !== 0) {
    return false;
  }
  const presented = Buffer.from(hex, "hex");
  if (presented.length * 2 !== hex.length) {
    return false;
  }
  const expected = createHmac("sha256", secret).update(body).digest();
  if (presented.length !== expected.length) {
    return false;
  }
  return timingSafeEqual(presented, expected);
};

const reviewTarget = (
  event: string | undefined,
  payload: typeof Webhook.Type,
): ReviewTarget | undefined => {
  if (event !== "pull_request") {
    return undefined;
  }
  if (payload.repository?.full_name !== repository) {
    return undefined;
  }
  if (
    payload.action === undefined ||
    payload.installation === undefined ||
    payload.pull_request === undefined
  ) {
    return undefined;
  }
  const draft = payload.pull_request.draft ?? false;
  if (
    payload.action === "ready_for_review" ||
    (payload.action === "opened" && !draft)
  ) {
    return {
      installationId: payload.installation.id,
      number: payload.pull_request.number,
    };
  }
  return undefined;
};

const mentionTarget = (
  event: string | undefined,
  payload: typeof Webhook.Type,
): MentionTarget | undefined => {
  if (event !== "issue_comment" || payload.action !== "created") {
    return undefined;
  }
  if (payload.repository?.full_name !== repository) {
    return undefined;
  }
  if (
    payload.installation === undefined ||
    payload.issue === undefined ||
    payload.issue.pull_request === undefined ||
    payload.comment === undefined
  ) {
    return undefined;
  }
  if (payload.comment.user?.type === "Bot") {
    return undefined;
  }
  const association = payload.comment.author_association;
  if (association === undefined || !writers.has(association)) {
    return undefined;
  }
  if (!mentionExpression("i").test(payload.comment.body)) {
    return undefined;
  }
  return {
    installationId: payload.installation.id,
    number: payload.issue.number,
    comment: payload.comment.body,
    title: payload.issue.title ?? "",
    issueBody: payload.issue.body ?? "",
  };
};

const rememberDelivery = (id: string) =>
  Database.pipe(
    Effect.flatMap((db) =>
      Effect.tryPromise({
        try: async () => {
          const inserted = await db
            .insert(githubDeliveries)
            .values({ id })
            .onConflictDoNothing()
            .returning({ id: githubDeliveries.id });
          return inserted.length > 0;
        },
        catch: (cause) => ({
          kind: "DatabaseFailed" as const,
          message:
            cause instanceof Error ? cause.message : "database request failed",
        }),
      }).pipe(Effect.tapError((error) => Effect.logError(error.message))),
    ),
  );

const base64url = (value: string) => Buffer.from(value).toString("base64url");

const appJwt = (cfg: GithubConfig) => {
  const now = Math.floor(Date.now() / 1000);
  const encodedHeader = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const encodedPayload = base64url(
    JSON.stringify({ iat: now - 60, exp: now + 540, iss: cfg.appId }),
  );
  const unsigned = `${encodedHeader}.${encodedPayload}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsigned);
  signer.end();
  const signature = signer
    .sign(Redacted.value(cfg.privateKey))
    .toString("base64url");
  return `${unsigned}.${signature}`;
};

const github = (
  token: string,
  path: string,
  init?: {
    readonly method: "GET" | "POST";
    readonly accept: string;
    readonly body?: string;
  },
) =>
  Effect.tryPromise({
    try: async () => {
      const response = await fetch(`${api}${path}`, {
        method: init?.method ?? "GET",
        ...(init?.body === undefined ? {} : { body: init.body }),
        headers: {
          accept: init?.accept ?? "application/vnd.github+json",
          authorization: `Bearer ${token}`,
          "user-agent": "nrdrm-agents",
          "x-github-api-version": "2022-11-28",
          ...(init?.body === undefined
            ? {}
            : { "content-type": "application/json" }),
        },
      });
      if (!response.ok) {
        throw Object.assign(new Error("github request failed"), {
          status: response.status,
        });
      }
      return await response.text();
    },
    catch: (cause): GithubFailed => ({
      kind: "GithubFailed",
      status:
        cause !== null &&
        typeof cause === "object" &&
        "status" in cause &&
        typeof cause.status === "number"
          ? cause.status
          : 0,
    }),
  });

const decodeJson = <A>(schema: Schema.Schema<A>, text: string) =>
  Schema.decodeUnknown(Schema.parseJson(schema))(text).pipe(
    Effect.mapError((): GithubFailed => ({ kind: "GithubFailed", status: 0 })),
  );

const installationToken = (cfg: GithubConfig, installationId: number) =>
  github(appJwt(cfg), `/app/installations/${installationId}/access_tokens`, {
    method: "POST",
    accept: "application/vnd.github+json",
  }).pipe(
    Effect.flatMap((text) => decodeJson(Token, text)),
    Effect.map((body) => body.token),
  );

const pullRequest = (token: string, number: number) => {
  const path = `/repos/${repository}/pulls/${number}`;
  return Effect.all({
    sha: github(token, path).pipe(
      Effect.flatMap((text) => decodeJson(Pull, text)),
      Effect.map((pull) => pull.head.sha),
    ),
    diff: github(token, path, {
      method: "GET",
      accept: "application/vnd.github.diff",
    }),
  });
};

const createReview = (
  token: string,
  number: number,
  sha: string,
  body: string,
  comments: readonly PostedComment[],
) =>
  github(token, `/repos/${repository}/pulls/${number}/reviews`, {
    method: "POST",
    accept: "application/vnd.github+json",
    body: JSON.stringify({
      commit_id: sha,
      body,
      event: "COMMENT",
      ...(comments.length === 0 ? {} : { comments }),
    }),
  }).pipe(Effect.asVoid);

const postReview = (
  token: string,
  number: number,
  sha: string,
  body: string,
  comments: readonly PostedComment[],
) =>
  createReview(token, number, sha, body, comments).pipe(
    Effect.catchIf(
      (error) => error.status === 422 && comments.length > 0,
      () => createReview(token, number, sha, body, []),
    ),
  );

const reviewPullRequest = (cfg: GithubConfig, target: ReviewTarget) =>
  installationToken(cfg, target.installationId).pipe(
    Effect.flatMap((token) =>
      pullRequest(token, target.number).pipe(
        Effect.map((pull) => ({ token, ...pull })),
      ),
    ),
    Effect.flatMap(({ token, sha, diff }) =>
      runReview(diff).pipe(
        Effect.matchEffect({
          onFailure: (error) => {
            if (
              error.kind === "InputRefused" ||
              error.kind === "DiffTooLarge"
            ) {
              return postReview(token, target.number, sha, skipped, []);
            }
            const message =
              error.kind === "ModelRequestFailed" ||
              error.kind === "DatabaseFailed"
                ? error.message
                : error.kind;
            return Effect.logError(message);
          },
          onSuccess: (result) =>
            "summary" in result
              ? postReview(
                  token,
                  target.number,
                  sha,
                  result.summary,
                  result.comments,
                )
              : Effect.logError("review did not match the schema"),
        }),
      ),
    ),
    Effect.catchAll((error: GithubFailed) =>
      Effect.logError(`github request failed: ${error.status}`),
    ),
  );

const pullDiff = (token: string, number: number) =>
  github(token, `/repos/${repository}/pulls/${number}`, {
    method: "GET",
    accept: "application/vnd.github.diff",
  });

const postComment = (token: string, number: number, body: string) =>
  github(token, `/repos/${repository}/issues/${number}/comments`, {
    method: "POST",
    accept: "application/vnd.github+json",
    body: JSON.stringify({ body }),
  }).pipe(Effect.asVoid);

const replyBody = (text: string) => {
  const stripped = text.replace(mentionExpression("gi"), "").trim();
  const body = stripped.length === 0 ? failedAnswer : stripped;
  return body.length > 60_000 ? body.slice(0, 60_000) : body;
};

const mentionInput = (target: MentionTarget, diff: string | undefined) =>
  [
    `Comment:\n${target.comment}`,
    `Pull request:\n${target.title}`,
    target.issueBody,
    diff === undefined
      ? "Diff:\nThe diff is too large to include."
      : `Diff:\n${diff}`,
  ]
    .filter((part) => part.length > 0)
    .join("\n\n");

const jsonObject = (text: string) => {
  const trimmed = text.trim();
  const fence = /^```(?:json)?\s*([\s\S]*?)\s*```$/.exec(trimmed);
  const body = (fence?.[1] ?? trimmed).trim();
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start === -1 || end < start) {
    throw new Error("mention was not an object");
  }
  return body.slice(start, end + 1);
};

const readMentionAction = (text: string) =>
  Effect.try({
    try: () => JSON.parse(jsonObject(text)) as unknown,
    catch: () => ({ kind: "MentionInvalid" as const }),
  }).pipe(
    Effect.flatMap((value) =>
      Schema.decodeUnknown(MentionAction)(value).pipe(
        Effect.mapError(() => ({ kind: "MentionInvalid" as const })),
      ),
    ),
  );

const loggedFailure = (error: { kind: string; message?: string }) => {
  const message =
    error.kind === "ModelRequestFailed" || error.kind === "DatabaseFailed"
      ? (error.message ?? error.kind)
      : error.kind;
  return Effect.logError(message);
};

const answerMention = (token: string, target: MentionTarget) =>
  pullDiff(token, target.number).pipe(
    Effect.flatMap((diff) =>
      runMention(
        mentionInput(target, diffTooLarge(diff) ? undefined : diff),
      ).pipe(
        Effect.matchEffect({
          onFailure: (error) => {
            if (error.kind === "InputRefused") {
              return postComment(token, target.number, cannotAnswer);
            }
            return loggedFailure(error).pipe(
              Effect.flatMap(() =>
                postComment(token, target.number, failedAnswer),
              ),
            );
          },
          onSuccess: (result) =>
            "text" in result
              ? postComment(token, target.number, replyBody(result.text))
              : postComment(token, target.number, failedAnswer),
        }),
      ),
    ),
  );

const respondToMention = (cfg: GithubConfig, target: MentionTarget) =>
  installationToken(cfg, target.installationId).pipe(
    Effect.flatMap((token) =>
      runMentionRoute(
        `Comment:\n${target.comment}\n\nPull request:\n${target.title}`,
      ).pipe(
        Effect.matchEffect({
          onFailure: (error) => {
            if (error.kind === "InputRefused") {
              return postComment(token, target.number, cannotAnswer);
            }
            return loggedFailure(error).pipe(
              Effect.flatMap(() =>
                postComment(token, target.number, failedAnswer),
              ),
            );
          },
          onSuccess: (result) => {
            if (!("text" in result)) {
              return postComment(token, target.number, failedAnswer);
            }
            return readMentionAction(result.text).pipe(
              Effect.matchEffect({
                onFailure: () => answerMention(token, target),
                onSuccess: (action) =>
                  action.action === "review"
                    ? reviewPullRequest(cfg, target)
                    : answerMention(token, target),
              }),
            );
          },
        }),
      ),
    ),
    Effect.catchAll((error: GithubFailed) =>
      Effect.logError(`github request failed: ${error.status}`),
    ),
  );

type WebhookFailure =
  | { kind: "InvalidSignature" }
  | { kind: "InvalidRequestBody" }
  | { kind: "DatabaseFailed"; message: string };

export const githubWebhook = HttpServerRequest.HttpServerRequest.pipe(
  Effect.flatMap((request) =>
    request.arrayBuffer.pipe(
      Effect.mapError((): WebhookFailure => ({ kind: "InvalidRequestBody" })),
      Effect.map((buffer) => ({
        request,
        raw: Buffer.from(buffer),
      })),
    ),
  ),
  Effect.flatMap(({ request, raw }) =>
    config.pipe(
      Effect.mapError(
        (): WebhookFailure => ({
          kind: "DatabaseFailed",
          message: "config unavailable",
        }),
      ),
      Effect.map((cfg) => ({ cfg, request, raw })),
    ),
  ),
  Effect.flatMap(({ cfg, request, raw }) => {
    if (
      !validSignature(
        Redacted.value(cfg.github.webhookSecret),
        raw,
        header(request.headers, "x-hub-signature-256"),
      )
    ) {
      return Effect.fail({ kind: "InvalidSignature" as const });
    }
    const delivery = header(request.headers, "x-github-delivery");
    const event = header(request.headers, "x-github-event");
    if (delivery === undefined || delivery.length === 0) {
      return Effect.fail({ kind: "InvalidRequestBody" as const });
    }
    return Schema.decodeUnknown(Schema.parseJson(Webhook))(
      raw.toString("utf8"),
    ).pipe(
      Effect.mapError((): WebhookFailure => ({ kind: "InvalidRequestBody" })),
      Effect.flatMap((payload) =>
        rememberDelivery(delivery).pipe(
          Effect.mapError(
            (error): WebhookFailure => ({
              kind: "DatabaseFailed",
              message: error.message,
            }),
          ),
          Effect.flatMap((fresh) => {
            if (!fresh) {
              return ok();
            }
            const review = reviewTarget(event, payload);
            if (review !== undefined) {
              return Effect.forkDaemon(
                reviewPullRequest(cfg.github, review),
              ).pipe(Effect.flatMap(() => ok()));
            }
            const mention = mentionTarget(event, payload);
            if (mention === undefined) {
              return ok();
            }
            return Effect.forkDaemon(
              respondToMention(cfg.github, mention),
            ).pipe(Effect.flatMap(() => ok()));
          }),
        ),
      ),
    );
  }),
  Effect.catchAll((error: WebhookFailure) => {
    if (error.kind === "InvalidSignature") {
      return jsonError(401, "invalid signature");
    }
    if (error.kind === "InvalidRequestBody") {
      return jsonError(400, "invalid request body");
    }
    return jsonError(500, "database request failed");
  }),
);
