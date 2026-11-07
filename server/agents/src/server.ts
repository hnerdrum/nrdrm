import { createServer } from 'node:http';

import { HttpRouter, HttpServer, HttpServerResponse } from '@effect/platform';
import { NodeHttpServer } from '@effect/platform-node';
import { Config, Layer } from 'effect';

import { complete } from './complete.js';
import { config } from './config.js';
import { DatabaseLive } from './database.js';
import { githubWebhook } from './github.js';
import { ModelRegistryLive } from './models.js';
import { getRun, runs } from './runs.js';

export const HttpLive = HttpRouter.empty.pipe(
  HttpRouter.get('/health', HttpServerResponse.json({ status: 'ok' })),
  HttpRouter.post('/webhooks/github', githubWebhook),
  HttpRouter.post('/complete', complete),
  HttpRouter.post('/runs', runs),
  HttpRouter.get('/runs/:id', getRun),
  HttpServer.serve(),
  HttpServer.withLogAddress,
  Layer.provide(ModelRegistryLive),
  Layer.provide(DatabaseLive),
  Layer.provide(
    NodeHttpServer.layerConfig(createServer, {
      port: config.pipe(Config.map((value) => value.port)),
    }),
  ),
);
