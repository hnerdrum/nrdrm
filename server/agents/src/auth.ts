import {
  Headers,
  HttpBody,
  HttpServerRequest,
  HttpServerResponse,
} from "@effect/platform";
import { Effect, Option, Redacted } from "effect";
import { createHash, timingSafeEqual } from "node:crypto";
import { config } from "./config.js";
import { jsonError } from "./utils.js";

type Response<E, R> = Effect.Effect<
  HttpServerResponse.HttpServerResponse,
  E,
  R
>;

export const requireApiKey = <E, R>(app: Response<E, R>) =>
  Effect.flatMap(config, ({ apiKey }) =>
    HttpServerRequest.HttpServerRequest.pipe(
      Effect.flatMap((request): Response<E | HttpBody.HttpBodyError, R> => {
        const header = Headers.get(request.headers, "authorization");
        const presented = Option.match(header, {
          onNone: () => undefined,
          onSome: bearer,
        });
        if (
          presented !== undefined &&
          sameSecret(Redacted.value(apiKey), presented)
        ) {
          return app;
        }
        return jsonError(401, "unauthorized");
      }),
    ),
  );

const bearer = (header: string) => {
  const match = /^Bearer\s+(\S+)$/i.exec(header);
  return match?.[1];
};

const sameSecret = (expected: string, presented: string) =>
  timingSafeEqual(
    createHash("sha256").update(expected).digest(),
    createHash("sha256").update(presented).digest(),
  );
