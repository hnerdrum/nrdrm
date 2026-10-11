import { Config, Option, Redacted } from "effect";

const secret = (name: string) =>
  Config.nonEmptyString(name).pipe(Config.map(Redacted.make));

const optionalSecret = (name: string) =>
  Config.string(name).pipe(
    Config.option,
    Config.map(Option.filter((value) => value.length > 0)),
    Config.map(Option.map(Redacted.make)),
  );

export const config = Config.all({
  port: Config.port("PORT").pipe(Config.withDefault(8090)),
  apiKey: secret("AGENTS_API_KEY"),
  scalewayApiKey: secret("SCALEWAY_API_KEY"),
  openaiApiKey: optionalSecret("OPENAI_API_KEY"),
}).pipe(
  Config.map((env) => ({
    port: env.port,
    apiKey: env.apiKey,
    scaleway: {
      apiKey: env.scalewayApiKey,
      baseUrl: "https://api.scaleway.ai/v1",
      modelId: "mistral-small-3.2-24b-instruct-2506",
    },
    openai: {
      apiKey: env.openaiApiKey,
      modelId: "gpt-4.1-mini",
    },
  })),
);
