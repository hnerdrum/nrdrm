import { Config, Option, Redacted } from 'effect';

const secret = (name: string) =>
  Config.nonEmptyString(name).pipe(Config.map(Redacted.make));

const optionalSecret = (name: string) =>
  Config.string(name).pipe(
    Config.option,
    Config.map(Option.filter((value) => value.length > 0)),
    Config.map(Option.map(Redacted.make)),
  );

const privateKey = Config.nonEmptyString('GITHUB_PRIVATE_KEY').pipe(
  Config.map((value) => Redacted.make(normalizePem(value))),
);

const normalizePem = (value: string) => {
  const trimmed = value.trim();
  const unquoted =
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
      ? trimmed.slice(1, -1)
      : trimmed;
  return unquoted.replace(/\\n/g, '\n');
};

export const config = Config.all({
  port: Config.port('PORT').pipe(Config.withDefault(8090)),
  scalewayApiKey: secret('SCALEWAY_API_KEY'),
  openaiApiKey: optionalSecret('OPENAI_API_KEY'),
  databaseUrl: Config.nonEmptyString('DATABASE_URL'),
  githubAppId: Config.nonEmptyString('GITHUB_APP_ID'),
  githubWebhookSecret: secret('GITHUB_WEBHOOK_SECRET'),
  githubPrivateKey: privateKey,
}).pipe(
  Config.map((env) => ({
    port: env.port,
    databaseUrl: env.databaseUrl,
    github: {
      appId: env.githubAppId,
      webhookSecret: env.githubWebhookSecret,
      privateKey: env.githubPrivateKey,
    },
    scaleway: {
      apiKey: env.scalewayApiKey,
      baseUrl: 'https://api.scaleway.ai/v1',
      modelId: 'mistral-small-3.2-24b-instruct-2506',
    },
    openai: {
      apiKey: env.openaiApiKey,
      modelId: 'gpt-4.1-mini',
    },
  })),
);
