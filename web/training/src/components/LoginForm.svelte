<script lang="ts">
  import { tick } from "svelte";
  import Button from "./Button.svelte";
  import TextField from "./TextField.svelte";

  type Props = {
    email?: string;
    error: string;
    submitting: boolean;
    onsubmit: (password: string) => void;
  };

  let { email = $bindable(""), error, submitting, onsubmit }: Props = $props();

  let password = $state("");
  let passwordInput = $state<HTMLInputElement | null>(null);
  let seenError = $state("");

  $effect(() => {
    if (!error) {
      seenError = "";
      return;
    }
    if (error === seenError) {
      return;
    }
    seenError = error;
    password = "";
    void tick().then(() => passwordInput?.focus());
  });

  function submit(event: SubmitEvent) {
    event.preventDefault();
    if (submitting) {
      return;
    }
    onsubmit(password);
  }
</script>

<main class="enter mx-auto grid max-w-104 gap-12 pt-[min(16vh,7rem)]">
  <h1 class="ml-[-0.03em] text-[min(16vw,4.75rem)] leading-none font-light tracking-[-0.055em]">
    Training
  </h1>
  <form class="grid gap-6" novalidate onsubmit={submit}>
    <TextField
      id="email"
      label="Email"
      type="email"
      name="email"
      autocomplete="username"
      bind:value={email}
    />
    <TextField
      id="password"
      label="Password"
      type="password"
      name="password"
      autocomplete="current-password"
      bind:value={password}
      bind:element={passwordInput}
    />
    {#if error}
      <p class="font-medium" role="alert">{error}</p>
    {/if}
    <Button type="submit" disabled={submitting}>Log in</Button>
  </form>
</main>
