<script lang="ts">
  import { durationParts, formatDuration } from "../format";
  import Odometer from "./Odometer.svelte";

  type Props = {
    seconds: number;
    index: number;
  };

  let { seconds, index }: Props = $props();

  const parts = $derived(durationParts(seconds));
  const minuteIndex = $derived(index + String(parts.hours).length);
</script>

<p
  class="flex items-end justify-end font-mono text-[clamp(2.75rem,14vw,3.75rem)] leading-none font-light tracking-tighter whitespace-nowrap tabular-nums wide:mt-12 wide:justify-start wide:text-[clamp(2.75rem,4.9vw,4.5rem)]"
>
  <span class="sr-only">{formatDuration(seconds)}</span>
  <span class="contents" aria-hidden="true">
    {#if parts.hours > 0}
      <Odometer value={String(parts.hours)} {index} />
      <span
        class="mb-[0.09em] ml-[0.14em] font-sans text-[max(1rem,0.3em)] leading-none font-normal tracking-normal text-muted"
        >h</span
      >
      <span class="ml-[0.24em] inline-flex">
        <Odometer value={String(parts.minutes).padStart(2, "0")} index={minuteIndex} />
      </span>
    {:else}
      <Odometer value={String(parts.minutes)} {index} />
    {/if}
    <span
      class="mb-[0.09em] ml-[0.14em] font-sans text-[max(1rem,0.3em)] leading-none font-normal tracking-normal text-muted"
      >m</span
    >
  </span>
</p>
