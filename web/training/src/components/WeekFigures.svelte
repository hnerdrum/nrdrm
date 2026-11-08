<script lang="ts">
  import { durationDigitCount, formatKm } from "../format";
  import { weekTotals } from "../domain";
  import type { LoggedSession } from "../log";
  import CountReadout from "./CountReadout.svelte";
  import DurationReadout from "./DurationReadout.svelte";

  type Props = {
    sessions: LoggedSession[];
  };

  let { sessions }: Props = $props();

  const totals = $derived(weekTotals(sessions));
  const rideIndex = $derived(durationDigitCount(totals.runSeconds));
  const skiIndex = $derived(rideIndex + durationDigitCount(totals.rideSeconds));
  const strengthIndex = $derived(skiIndex + durationDigitCount(totals.skiSeconds));

  const tile =
    "fig grid min-h-28 grid-cols-[1fr_auto] items-center gap-x-4 px-6 py-6 wide:flex wide:min-h-[15.5rem] wide:flex-col wide:items-stretch wide:justify-start wide:p-8";
  const label = "text-base font-medium tracking-[0.16em] text-muted uppercase";
</script>

<section
  class="figs grid overflow-hidden rounded-[28px] border border-line bg-field shadow-[0_30px_60px_-40px_rgba(0,0,0,0.8)] wide:grid-cols-4"
  aria-label="Week totals"
>
  <article class={tile}>
    <h2 class={label}>Run</h2>
    <DurationReadout seconds={totals.runSeconds} index={0} />
  </article>
  <article class={tile}>
    <h2 class={label}>Ride</h2>
    <DurationReadout seconds={totals.rideSeconds} index={rideIndex} />
  </article>
  <article class={tile}>
    <h2 class={label}>Ski</h2>
    <DurationReadout seconds={totals.skiSeconds} index={skiIndex} />
    <div class="col-span-full mt-4 grid gap-1 wide:mt-auto wide:pt-6">
      <p class="flex justify-between gap-4 text-muted">
        <span>All ski</span>
        <b class="font-mono font-normal text-fg tabular-nums">{formatKm(totals.skiMetres)}</b>
      </p>
      <p class="flex justify-between gap-4 text-muted">
        <span>With pack</span>
        <b class="font-mono font-normal text-fg tabular-nums">{formatKm(totals.packMetres)}</b>
      </p>
    </div>
  </article>
  <article class={tile}>
    <h2 class={label}>Strength</h2>
    <CountReadout count={totals.strengthSessions} index={strengthIndex} />
  </article>
</section>

<style>
  .fig + .fig {
    border-top: 1px solid var(--color-line);
  }

  @media (min-width: 960px) {
    .fig + .fig {
      border-top: 0;
      border-left: 1px solid var(--color-line);
    }
  }
</style>
