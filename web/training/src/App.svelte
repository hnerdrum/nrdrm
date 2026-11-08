<script lang="ts">
  import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query";
  import { isUnauthorized } from "./api/client";
  import { currentSession, identityQueryKey, login } from "./api/identity";
  import LoginForm from "./components/LoginForm.svelte";
  import Training from "./components/Training.svelte";
  import Button from "./components/Button.svelte";

  const queryClient = useQueryClient();
  let email = $state("");

  const session = createQuery(() => ({
    queryKey: identityQueryKey,
    queryFn: currentSession,
  }));

  const loginMutation = createMutation(() => ({
    mutationFn: (password: string) => login(email, password),
    meta: { credentials: true },
    onSuccess: () => {
      queryClient.setQueryData(identityQueryKey, { email });
    },
  }));

  const loginError = $derived.by(() => {
    if (!loginMutation.isError) {
      return "";
    }
    if (isUnauthorized(loginMutation.error)) {
      return "Wrong email or password.";
    }
    return "Couldn't sign in. Try again.";
  });

  function onLogin(password: string) {
    if (loginMutation.isPending) {
      return;
    }
    loginMutation.mutate(password);
  }
</script>

{#if session.isPending}
  <!-- Restoring the session. -->
{:else if session.isError}
  <main class="enter mx-auto grid max-w-104 gap-8 pt-[min(16vh,7rem)]">
    <h1 class="ml-[-0.03em] text-[min(16vw,4.75rem)] leading-none font-light tracking-[-0.055em]">
      Training
    </h1>
    <p class="font-medium" role="alert">Couldn't reach the server.</p>
    <Button disabled={session.isFetching} onclick={() => session.refetch()}>Try again</Button>
  </main>
{:else if session.data}
  <Training />
{:else}
  <LoginForm
    bind:email
    error={loginError}
    submitting={loginMutation.isPending}
    onsubmit={onLogin}
  />
{/if}
