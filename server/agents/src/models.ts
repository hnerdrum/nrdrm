import { createOpenAI } from "@ai-sdk/openai";
import {
  generateText,
  ToolLoopAgent,
  type LanguageModel,
  type ToolSet,
} from "ai";
import { Effect, Layer, Option, Redacted } from "effect";
import { config } from "./config.js";
import { type ModelError } from "./errors.js";

export const modelProviders = ["scaleway", "openai"] as const;
export type ModelProvider = (typeof modelProviders)[number];

export type LoopRequest = {
  readonly instructions: string;
  readonly prompt: string;
  readonly tools: ToolSet;
};

type Model = {
  readonly provider: ModelProvider;
  readonly modelId: string;
  readonly complete: (prompt: string) => Promise<Completion>;
  readonly loop: (request: LoopRequest) => Promise<Completion>;
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
    readonly loop: (
      provider: ModelProvider,
      request: LoopRequest,
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
    const call = (
      name: ModelProvider,
      run: (model: Model) => Promise<Completion>,
    ) => {
      const model = entries[name];
      if (model === undefined) {
        return Effect.fail({
          kind: "ProviderNotConfigured" as const,
          provider: name,
        });
      }
      return Effect.tryPromise({
        try: () => run(model),
        catch: (cause) => ({
          kind: "ModelRequestFailed" as const,
          name: model.modelId,
          message:
            cause instanceof Error ? cause.message : "model request failed",
        }),
      }).pipe(Effect.tapError((error) => Effect.logError(error.message)));
    };
    return {
      complete: (name, prompt) => call(name, (model) => model.complete(prompt)),
      loop: (name, request) => call(name, (model) => model.loop(request)),
    };
  }),
);

const scaleway = (args: {
  modelId: string;
  apiKey: Redacted.Redacted;
  baseUrl: string;
}): Model => {
  const model = createOpenAI({
    apiKey: Redacted.value(args.apiKey),
    baseURL: args.baseUrl,
  }).chat(args.modelId);
  return {
    modelId: args.modelId,
    provider: "scaleway",
    complete: async (prompt) => {
      const result = await generateText({ model, prompt });
      return {
        text: result.text,
        provider: "scaleway",
        modelId: args.modelId,
      };
    },
    loop: (request) => loop(model, "scaleway", args.modelId, request),
  };
};

const openai = (args: {
  modelId: string;
  apiKey: Redacted.Redacted;
}): Model => {
  const model = createOpenAI({
    apiKey: Redacted.value(args.apiKey),
  }).chat(args.modelId);
  return {
    modelId: args.modelId,
    provider: "openai",
    complete: async (prompt) => {
      const result = await generateText({ model, prompt });
      return {
        text: result.text,
        provider: "openai",
        modelId: args.modelId,
      };
    },
    loop: (request) => loop(model, "openai", args.modelId, request),
  };
};

const loop = async (
  model: LanguageModel,
  provider: ModelProvider,
  modelId: string,
  request: LoopRequest,
): Promise<Completion> => {
  const agent = new ToolLoopAgent({
    model,
    instructions: request.instructions,
    tools: request.tools,
  });
  const result = await agent.generate({ prompt: request.prompt });
  return {
    text: result.text,
    provider,
    modelId,
  };
};
