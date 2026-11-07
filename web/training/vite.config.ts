import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig, loadEnv } from 'vite';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const gatewayOrigin = env.GATEWAY_URL || 'http://localhost:8080';

  return {
    plugins: [tailwindcss(), svelte()],
    server: {
      port: 5173,
      proxy: {
        '/training': gatewayOrigin,
        '/identity': gatewayOrigin,
      },
    },
  };
});
