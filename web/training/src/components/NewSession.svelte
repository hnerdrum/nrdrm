<script lang="ts">
  import Button from "./Button.svelte";

  type Props = {
    oncancel: () => void;
  };

  let { oncancel }: Props = $props();
</script>

<div class="mx-auto flex min-h-dvh max-w-lg flex-col">
  <header class="-ml-3 pt-3">
    <Button variant="quiet" onclick={oncancel}>Cancel</Button>
  </header>
  <h1 class="mt-4 text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
    New session
  </h1>
</div>
