import { HttpRouter, HttpServer, HttpServerResponse } from "@effect/platform";
import { NodeHttpServer } from "@effect/platform-node";
import { Config, Layer } from "effect";
import { createServer } from "node:http";
import { requireApiKey } from "./auth.js";
import { complete } from "./complete.js";
import { config } from "./config.js";
import { ModelRegistryLive } from "./models.js";

const api = HttpRouter.empty.pipe(
  HttpRouter.post("/complete", complete),
  HttpRouter.use(requireApiKey),
);

export const HttpLive = HttpRouter.empty.pipe(
  HttpRouter.get("/health", HttpServerResponse.json({ status: "ok" })),
  HttpRouter.concat(api),
  HttpServer.serve(),
  HttpServer.withLogAddress,
  Layer.provide(ModelRegistryLive),
  Layer.provide(
    NodeHttpServer.layerConfig(createServer, {
      port: config.pipe(Config.map((value) => value.port)),
    }),
  ),
);
