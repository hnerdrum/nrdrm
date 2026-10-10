import { Config } from "effect";

export const port = Config.port("PORT").pipe(Config.withDefault(8090));
