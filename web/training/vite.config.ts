import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const trainingOrigin = env.TRAINING_URL || "http://localhost:8082";

  return {
    plugins: [svelte()],
    server: {
      port: 5173,
      proxy: {
        "/api": trainingOrigin,
      },
    },
  };
});
