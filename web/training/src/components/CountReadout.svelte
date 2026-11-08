<script lang="ts">
  import { plural } from "../format";
  import Odometer from "./Odometer.svelte";

  type Props = {
    count: number;
    index: number;
  };

  let { count, index }: Props = $props();
  const label = $derived(plural(count, "session", "sessions"));
</script>

<p
  class="flex items-end justify-end font-mono text-[clamp(2.75rem,14vw,3.75rem)] leading-none font-light tracking-tighter whitespace-nowrap tabular-nums wide:mt-12 wide:justify-start wide:text-[clamp(2.75rem,4.9vw,4.5rem)]"
>
  <span class="sr-only">{label}</span>
  <span class="contents" aria-hidden="true">
    <Odometer value={String(count)} {index} />
    <span
      class="mb-[0.09em] ml-[0.35em] font-sans text-[max(1rem,0.3em)] leading-none font-normal tracking-normal text-muted"
      >{count === 1 ? "session" : "sessions"}</span
    >
  </span>
</p>
