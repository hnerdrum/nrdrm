import { ModelProvider } from "./models.js";

export type ApiError = InvalidRequestBodyError | UnknownSkill | ModelError;

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
