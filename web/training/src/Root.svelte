<script lang="ts">
  import {
    MutationCache,
    QueryCache,
    QueryClient,
    QueryClientProvider,
  } from "@tanstack/svelte-query";
  import { identityQueryKey } from "./api/identity";
  import { isUnauthorized } from "./api/client";
  import { sessionsQueryKey } from "./api/sessions";
  import App from "./App.svelte";
  import Button from "./components/Button.svelte";

  const queryClient = new QueryClient({
    queryCache: new QueryCache({
      onError(error) {
        if (isUnauthorized(error)) {
          signOut();
        }
      },
    }),
    mutationCache: new MutationCache({
      onError(error, _variables, _result, _mutation, context) {
        if (context.meta?.credentials) {
          return;
        }
        if (isUnauthorized(error)) {
          signOut();
        }
      },
    }),
    defaultOptions: {
      queries: { retry: false },
    },
  });

  function signOut() {
    queryClient.setQueryData(identityQueryKey, null);
    void queryClient.removeQueries({ queryKey: sessionsQueryKey });
  }
</script>

<svelte:boundary onerror={(error) => console.error(error)}>
  <QueryClientProvider client={queryClient}>
    <App />
  </QueryClientProvider>

  {#snippet failed(_error, reset)}
    <main class="relative grid min-h-dvh content-center">
      <div class="pointer-events-none absolute top-[16%] -left-16" aria-hidden="true">
        <div class="offbeat-glow size-72 rounded-full bg-accent/25 blur-3xl"></div>
      </div>
      <div class="offbeat relative grid max-w-104 gap-8">
        <p class="offbeat-line font-mono text-[0.7rem] tracking-[0.22em] text-muted uppercase">
          Off tempo
        </p>
        <h1
          class="text-[clamp(3.25rem,14vw,5.5rem)] leading-[0.9] font-light tracking-[-0.045em]"
        >
          <span class="offbeat-word block">Something</span>
          <span class="offbeat-word block">went</span>
          <span class="offbeat-word block text-accent">wrong.</span>
        </h1>
        <div class="offbeat-line">
          <Button variant="accent" class="w-full" onclick={reset}>Try again</Button>
        </div>
      </div>
    </main>
  {/snippet}
</svelte:boundary>
