import { HttpServerResponse } from "@effect/platform";
import { Effect } from "effect";
import { ApiError } from "./errors.js";

export const jsonError = (status: number, error: string) =>
  HttpServerResponse.json({ error }).pipe(
    Effect.map(HttpServerResponse.setStatus(status)),
  );

export const mapApiError = (error: ApiError) => {
  if (error.kind === "InvalidRequestBody") {
    return jsonError(400, "invalid request body");
  }
  if (error.kind === "UnknownSkill") {
    return jsonError(404, `unknown skill: ${error.skill}`);
  }
  if (error.kind === "InputRefused") {
    return HttpServerResponse.json({
      error: "input refused",
      id: error.id,
    }).pipe(Effect.map(HttpServerResponse.setStatus(400)));
  }
  if (error.kind === "DiffTooLarge") {
    return HttpServerResponse.json({
      error: "diff too large",
      id: error.id,
    }).pipe(Effect.map(HttpServerResponse.setStatus(400)));
  }
  if (error.kind === "RunNotFound") {
    return jsonError(404, "run not found");
  }
  if (error.kind === "DatabaseFailed") {
    return jsonError(500, "database request failed");
  }
  if (error.kind === "ProviderNotConfigured") {
    return jsonError(400, `provider not configured: ${error.provider}`);
  }
  if (error.kind === "ModelRequestFailed") {
    return jsonError(502, "model request failed");
  }
  return error satisfies never;
};
