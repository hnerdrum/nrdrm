import { HttpServerRequest, HttpServerResponse } from "@effect/platform";
import { Effect, Schema } from "effect";
import { ApiError } from "./errors.js";
import { modelProviders, ModelRegistry } from "./models.js";
import { jsonError } from "./utils.js";

const CompleteRequest = Schema.Struct({
  prompt: Schema.NonEmptyString,
  model: Schema.Literal(...modelProviders),
});

export const complete = HttpServerRequest.schemaBodyJson(CompleteRequest).pipe(
  Effect.mapError(() => ({ kind: "InvalidRequestBody" }) as const),
  Effect.flatMap((body) =>
    ModelRegistry.pipe(
      Effect.flatMap((registry) => registry.complete(body.model, body.prompt)),
    ),
  ),
  Effect.matchEffect({
    onFailure: (error) => mapApiError(error),
    onSuccess: (result) => HttpServerResponse.json(result),
  }),
);

const mapApiError = (error: ApiError) => {
  if (error.kind === "InvalidRequestBody") {
    return jsonError(400, "invalid request body");
  }
  if (error.kind === "ProviderNotConfigured") {
    return jsonError(400, `provider not configured: ${error.provider}`);
  }
  if (error.kind === "ModelRequestFailed") {
    return jsonError(502, "model request failed");
  }
  return error satisfies never;
};
