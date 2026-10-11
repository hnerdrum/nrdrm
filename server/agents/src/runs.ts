import { HttpServerRequest, HttpServerResponse } from "@effect/platform";
import { Effect, Schema } from "effect";
import { type ModelError, type UnknownSkill } from "./errors.js";
import { modelProviders, type ModelProvider, ModelRegistry } from "./models.js";
import { loadSkill } from "./skills.js";
import { mapApiError } from "./utils.js";

const RunRequest = Schema.Struct({
  skill: Schema.NonEmptyString,
  input: Schema.NonEmptyString,
  model: Schema.Literal(...modelProviders),
});

type RunResult = {
  readonly text: string;
  readonly skill: string;
  readonly actor: string;
  readonly provider: ModelProvider;
  readonly modelId: string;
};

export const runs = HttpServerRequest.schemaBodyJson(RunRequest).pipe(
  Effect.mapError(() => ({ kind: "InvalidRequestBody" }) as const),
  Effect.flatMap(
    (
      body: typeof RunRequest.Type,
    ): Effect.Effect<RunResult, UnknownSkill | ModelError, ModelRegistry> => {
      const skill = loadSkill(body.skill);
      if (skill === undefined) {
        return Effect.fail({ kind: "UnknownSkill", skill: body.skill });
      }
      return ModelRegistry.pipe(
        Effect.flatMap((registry) =>
          registry.loop(body.model, {
            instructions: skill.instructions,
            prompt: body.input,
            tools: skill.tools,
          }),
        ),
        Effect.map((completion) => ({
          text: completion.text,
          skill: skill.name,
          actor: `agent:${skill.name}`,
          provider: completion.provider,
          modelId: completion.modelId,
        })),
      );
    },
  ),
  Effect.matchEffect({
    onFailure: (error) => mapApiError(error),
    onSuccess: (result) => HttpServerResponse.json(result),
  }),
);
