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
    <main class="enter mx-auto grid max-w-104 gap-8 pt-[min(16vh,7rem)]">
      <h1 class="text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
        Something went wrong.
      </h1>
      <Button onclick={reset}>Try again</Button>
    </main>
  {/snippet}
</svelte:boundary>
