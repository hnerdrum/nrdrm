import { ModelProvider } from "./models.js";

export type ApiError =
  | InvalidRequestBodyError
  | UnknownSkill
  | InputRefused
  | DiffTooLarge
  | RunNotFound
  | DatabaseError
  | ModelError;

export type InputRefused = { kind: "InputRefused"; id: string };

export type DiffTooLarge = { kind: "DiffTooLarge"; id: string };

export type RunNotFound = { kind: "RunNotFound" };

export type DatabaseError = {
  kind: "DatabaseFailed";
  message: string;
};

export type InvalidRequestBodyError = { kind: "InvalidRequestBody" };

export type UnknownSkill = {
  kind: "UnknownSkill";
  skill: string;
};

export type ModelError = ProviderNotConfigured | ModelRequestFailedError;

export type ProviderNotConfigured = {
  kind: "ProviderNotConfigured";
  provider: ModelProvider;
};

export type ModelRequestFailedError = {
  kind: "ModelRequestFailed";
  name: string;
  message: string;
};
