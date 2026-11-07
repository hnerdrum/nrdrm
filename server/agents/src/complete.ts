import { HttpServerRequest, HttpServerResponse } from '@effect/platform';
import { Effect, Schema } from 'effect';

import { modelProviders, ModelRegistry } from './models.js';
import { mapApiError } from './utils.js';

const CompleteRequest = Schema.Struct({
  prompt: Schema.NonEmptyString,
  model: Schema.Literal(...modelProviders),
});

export const complete = HttpServerRequest.schemaBodyJson(CompleteRequest).pipe(
  Effect.mapError(() => ({ kind: 'InvalidRequestBody' }) as const),
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
