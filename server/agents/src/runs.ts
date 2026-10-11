import {
  HttpRouter,
  HttpServerRequest,
  HttpServerResponse,
} from "@effect/platform";
import { eq } from "drizzle-orm";
import { Effect, Schema } from "effect";
import { Database } from "./database.js";
import {
  type DatabaseError,
  type DiffTooLarge,
  type InputRefused,
  type ModelError,
  type UnknownSkill,
} from "./errors.js";
import {
  type LoopResult,
  modelProviders,
  type ModelProvider,
  ModelRegistry,
} from "./models.js";
import { sensitiveData } from "./policy.js";
import {
  diffTooLarge,
  readReview,
  type ReviewComment,
  reviewSkill,
} from "./review.js";
import { agentRuns, type RunRow } from "./schema.js";
import { type Skill, loadSkill } from "./skills.js";
import { mapApiError } from "./utils.js";

const RunRequest = Schema.Struct({
  skill: Schema.NonEmptyString,
  input: Schema.NonEmptyString,
  model: Schema.Literal(...modelProviders),
});

const RunParams = Schema.Struct({
  id: Schema.UUID,
});

type RunIdentity = {
  readonly id: string;
  readonly skill: string;
  readonly actor: string;
  readonly provider: ModelProvider;
  readonly modelId: string;
};

type RunResult =
  | (RunIdentity & { readonly text: string })
  | (RunIdentity & {
      readonly summary: string;
      readonly comments: readonly ReviewComment[];
    });

type NewRun = {
  readonly skill: string;
  readonly actor: string;
  readonly status: string;
  readonly modelId: string;
  readonly inputTokens: number;
  readonly outputTokens: number;
  readonly startedAt: Date;
};

const startRun = (
  body: typeof RunRequest.Type,
): Effect.Effect<
  RunResult,
  UnknownSkill | InputRefused | DiffTooLarge | ModelError | DatabaseError,
  ModelRegistry | Database
> => {
  const skill = loadSkill(body.skill);
  if (skill === undefined) {
    return Effect.fail({ kind: "UnknownSkill", skill: body.skill });
  }
  const startedAt = new Date();
  const actor = `agent:${skill.name}`;
  if (sensitiveData(body.input)) {
    return refuseRun(
      {
        skill: skill.name,
        actor,
        status: "refused",
        modelId: body.model,
        inputTokens: 0,
        outputTokens: 0,
        startedAt,
      },
      (id) => ({ kind: "InputRefused" as const, id }),
    );
  }
  if (skill.name === reviewSkill && diffTooLarge(body.input)) {
    return refuseRun(
      {
        skill: skill.name,
        actor,
        status: "too-large",
        modelId: body.model,
        inputTokens: 0,
        outputTokens: 0,
        startedAt,
      },
      (id) => ({ kind: "DiffTooLarge" as const, id }),
    );
  }
  return ModelRegistry.pipe(
    Effect.flatMap((registry) =>
      registry
        .loop(body.model, {
          instructions: skill.instructions,
          prompt: body.input,
          tools: skill.tools,
        })
        .pipe(
          Effect.tapError(
            (error): Effect.Effect<void, DatabaseError, Database> => {
              if (error.kind !== "ModelRequestFailed") {
                return Effect.void;
              }
              return recordRun({
                skill: skill.name,
                actor,
                status: "failed",
                modelId: error.name,
                inputTokens: 0,
                outputTokens: 0,
                startedAt,
              }).pipe(Effect.asVoid);
            },
          ),
        ),
    ),
    Effect.flatMap((completion) =>
      finishRun(skill, body.input, actor, startedAt, completion),
    ),
  );
};

const refuseRun = <E extends InputRefused | DiffTooLarge>(
  row: NewRun,
  fail: (id: string) => E,
) =>
  recordRun(row).pipe(Effect.flatMap((stored) => Effect.fail(fail(stored.id))));

const finishRun = (
  skill: Skill,
  input: string,
  actor: string,
  startedAt: Date,
  completion: LoopResult,
): Effect.Effect<RunResult, ModelError | DatabaseError, Database> => {
  const row = {
    skill: skill.name,
    actor,
    modelId: completion.modelId,
    inputTokens: completion.inputTokens,
    outputTokens: completion.outputTokens,
    startedAt,
  };
  const identity = {
    skill: skill.name,
    actor,
    provider: completion.provider,
    modelId: completion.modelId,
  };
  if (skill.name !== reviewSkill) {
    return recordRun({ ...row, status: "finished" }).pipe(
      Effect.map((stored) => ({
        ...identity,
        id: stored.id,
        text: completion.text,
      })),
    );
  }
  return readReview(input, completion.text).pipe(
    Effect.matchEffect({
      onFailure: () =>
        Effect.logError("review did not match the schema").pipe(
          Effect.flatMap(() => recordRun({ ...row, status: "failed" })),
          Effect.flatMap(() =>
            Effect.fail({
              kind: "ModelRequestFailed" as const,
              name: completion.modelId,
              message: "review did not match the schema",
            }),
          ),
        ),
      onSuccess: (review) =>
        recordRun({ ...row, status: "finished" }).pipe(
          Effect.map((stored) => ({
            ...identity,
            id: stored.id,
            summary: review.summary,
            comments: review.comments,
          })),
        ),
    }),
  );
};

const recordRun = (row: NewRun) =>
  Database.pipe(
    Effect.flatMap((db) =>
      Effect.tryPromise({
        try: async () => {
          const inserted = await db
            .insert(agentRuns)
            .values({ ...row, finishedAt: new Date() })
            .returning();
          const run = inserted[0];
          if (run === undefined) {
            throw new Error("insert returned no row");
          }
          return run;
        },
        catch: (cause) => ({
          kind: "DatabaseFailed" as const,
          message:
            cause instanceof Error ? cause.message : "database request failed",
        }),
      }).pipe(Effect.tapError((error) => Effect.logError(error.message))),
    ),
  );

export const runs = HttpServerRequest.schemaBodyJson(RunRequest).pipe(
  Effect.mapError(() => ({ kind: "InvalidRequestBody" }) as const),
  Effect.flatMap(startRun),
  Effect.matchEffect({
    onFailure: (error) => mapApiError(error),
    onSuccess: (result) => HttpServerResponse.json(result),
  }),
);

export const getRun = HttpRouter.schemaPathParams(RunParams).pipe(
  Effect.mapError(() => ({ kind: "RunNotFound" }) as const),
  Effect.flatMap(({ id }) =>
    Database.pipe(
      Effect.flatMap((db) =>
        Effect.tryPromise({
          try: () => db.select().from(agentRuns).where(eq(agentRuns.id, id)),
          catch: (cause) => ({
            kind: "DatabaseFailed" as const,
            message:
              cause instanceof Error
                ? cause.message
                : "database request failed",
          }),
        }).pipe(Effect.tapError((error) => Effect.logError(error.message))),
      ),
      Effect.flatMap((rows) => {
        const row = rows[0];
        if (row === undefined) {
          return Effect.fail({ kind: "RunNotFound" } as const);
        }
        return Effect.succeed(row);
      }),
    ),
  ),
  Effect.matchEffect({
    onFailure: (error) => mapApiError(error),
    onSuccess: (row) => HttpServerResponse.json(fromDbRun(row)),
  }),
);

export const runReview = (input: string) =>
  startRun({ skill: reviewSkill, input, model: "scaleway" });

export const runMention = (input: string) =>
  startRun({ skill: "mention", input, model: "scaleway" });

export const runMentionRoute = (input: string) =>
  startRun({ skill: "mention-route", input, model: "scaleway" });

const fromDbRun = (row: RunRow) => ({
  id: row.id,
  skill: row.skill,
  actor: row.actor,
  status: row.status,
  modelId: row.modelId,
  inputTokens: row.inputTokens,
  outputTokens: row.outputTokens,
  startedAt: row.startedAt.toISOString(),
  finishedAt: row.finishedAt.toISOString(),
});
