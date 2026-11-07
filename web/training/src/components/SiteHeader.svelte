<script lang="ts">
  import type { Snippet } from "svelte";

  type Props = {
    children?: Snippet;
  };

  let { children }: Props = $props();
</script>

<header class="mx-auto grid max-w-[68rem] grid-cols-[1fr_auto] items-center pt-3">
  <p class="text-base font-semibold tracking-[0.18em] uppercase">Training</p>
  {#if children}
    <div class="-mr-3">
      {@render children()}
    </div>
  {/if}
</header>
