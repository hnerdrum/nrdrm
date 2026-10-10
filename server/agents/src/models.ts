import { createOpenAI } from "@ai-sdk/openai";
import { generateText } from "ai";
import { Effect, Layer, Option, Redacted } from "effect";
import { config } from "./config.js";
import { type ModelError } from "./errors.js";

export const modelProviders = ["scaleway", "openai"] as const;
export type ModelProvider = (typeof modelProviders)[number];

type Model = {
  readonly provider: ModelProvider;
  readonly modelId: string;
  readonly complete: (prompt: string) => Promise<Completion>;
};

export type Completion = {
  readonly text: string;
  readonly provider: ModelProvider;
  readonly modelId: string;
};

export class ModelRegistry extends Effect.Tag("ModelRegistry")<
  ModelRegistry,
  {
    readonly complete: (
      provider: ModelProvider,
      prompt: string,
    ) => Effect.Effect<Completion, ModelError>;
  }
>() {}

export const ModelRegistryLive = Layer.effect(
  ModelRegistry,
  Effect.map(config, (config) => {
    const entries: Record<ModelProvider, Model | undefined> = {
      scaleway: scaleway(config.scaleway),
      openai: Option.isSome(config.openai.apiKey)
        ? openai({
            modelId: config.openai.modelId,
            apiKey: config.openai.apiKey.value,
          })
        : undefined,
    };
    return {
      complete: (name, prompt) => {
        const model = entries[name];
        if (model === undefined) {
          return Effect.fail({
            kind: "ProviderNotConfigured" as const,
            provider: name,
          });
        }
        return Effect.tryPromise({
          try: () => model.complete(prompt),
          catch: (cause) => ({
            kind: "ModelRequestFailed" as const,
            name: model.modelId,
            message:
              cause instanceof Error ? cause.message : "model request failed",
          }),
        }).pipe(Effect.tapError((error) => Effect.logError(error.message)));
      },
    };
  }),
);

const scaleway = (args: {
  modelId: string;
  apiKey: Redacted.Redacted;
  baseUrl: string;
}): Model => ({
  modelId: args.modelId,
  provider: "scaleway",
  complete: async (prompt: string) => {
    const provider = createOpenAI({
      apiKey: Redacted.value(args.apiKey),
      baseURL: args.baseUrl,
    });
    const result = await generateText({
      model: provider.chat(args.modelId),
      prompt,
    });
    return {
      text: result.text,
      provider: "scaleway",
      modelId: args.modelId,
    };
  },
});

const openai = (args: {
  modelId: string;
  apiKey: Redacted.Redacted;
}): Model => ({
  modelId: args.modelId,
  provider: "openai",
  complete: async (prompt: string) => {
    const provider = createOpenAI({
      apiKey: Redacted.value(args.apiKey),
    });
    const result = await generateText({
      model: provider.chat(args.modelId),
      prompt,
    });
    return {
      text: result.text,
      provider: "openai",
      modelId: args.modelId,
    };
  },
});
