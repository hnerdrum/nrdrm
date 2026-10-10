import { HttpRouter, HttpServer, HttpServerResponse } from "@effect/platform";
import { NodeHttpServer } from "@effect/platform-node";
import { Config, Layer } from "effect";
import { createServer } from "node:http";
import { complete } from "./complete.js";
import { config } from "./config.js";
import { ModelRegistryLive } from "./models.js";

export const HttpLive = HttpRouter.empty.pipe(
  HttpRouter.get("/health", HttpServerResponse.json({ status: "ok" })),
  HttpRouter.post("/complete", complete),
  HttpServer.serve(),
  HttpServer.withLogAddress,
  Layer.provide(ModelRegistryLive),
  Layer.provide(
    NodeHttpServer.layerConfig(createServer, {
      port: config.pipe(Config.map((value) => value.port)),
    }),
  ),
);
