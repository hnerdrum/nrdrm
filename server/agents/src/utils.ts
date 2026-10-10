import { HttpServerResponse } from "@effect/platform";
import { Effect } from "effect";

export const jsonError = (status: number, error: string) =>
  HttpServerResponse.json({ error }).pipe(
    Effect.map(HttpServerResponse.setStatus(status)),
  );
