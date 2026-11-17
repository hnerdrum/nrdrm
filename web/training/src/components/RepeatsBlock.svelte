<script lang="ts">
  import { intervalReadout, type DistanceSport, type DraftInterval } from "../draft";
  import BlockActions from "./BlockActions.svelte";

  type Field = "repetitions" | "metres" | "minutes" | "seconds" | "recovery";

  type Props = {
    sport: DistanceSport;
    interval: DraftInterval;
    /** Its place among all the blocks, for moving it. */
    index: number;
    total: number;
    /** Its number among the intervals, for its label. */
    number: number;
    onedit: (field: Field, value: string) => void;
    onmove: (direction: -1 | 1) => void;
    onremove: () => void;
  };

  let { sport, interval, index, total, number, onedit, onmove, onremove }: Props = $props();

  const inputClass =
    "min-h-[52px] w-full min-w-0 rounded-2xl border border-edge bg-bg px-4 font-mono text-lg tabular-nums transition-[border-color] hover:border-muted focus-visible:border-accent focus-visible:outline-offset-1";

  const readout = $derived(intervalReadout(sport, interval));

  function text(event: Event): string {
    const target = event.currentTarget;
    return target instanceof HTMLInputElement ? target.value : "";
  }
</script>

<section class="grid gap-5 rounded-3xl border border-line bg-field p-5" aria-label="Interval {number}">
  <h2 class="text-lg font-medium">Interval {number}</h2>
  <div class="grid grid-cols-2 gap-4">
    <label class="grid gap-2" for="interval-{interval.key}-repeats">
      <span class="text-muted">Repeats</span>
      <input
        id="interval-{interval.key}-repeats"
        class={inputClass}
        inputmode="numeric"
        autocomplete="off"
        value={interval.repetitions}
        oninput={(event) => onedit("repetitions", text(event))}
      />
    </label>
    <label class="grid gap-2" for="interval-{interval.key}-metres">
      <span class="text-muted">Metres</span>
      <input
        id="interval-{interval.key}-metres"
        class={inputClass}
        inputmode="numeric"
        autocomplete="off"
        placeholder="Optional"
        aria-label="Metres of one repeat. Leave empty when you only know the time."
        value={interval.metres}
        oninput={(event) => onedit("metres", text(event))}
      />
    </label>
  </div>
  <div class="grid gap-2">
    <span class="text-muted">Each repeat</span>
    <div class="grid grid-cols-2 gap-4">
      <label class="grid gap-2" for="interval-{interval.key}-minutes">
        <span class="text-muted">Min</span>
        <input
          id="interval-{interval.key}-minutes"
          class={inputClass}
          inputmode="numeric"
          autocomplete="off"
          value={interval.minutes}
          oninput={(event) => onedit("minutes", text(event))}
        />
      </label>
      <label class="grid gap-2" for="interval-{interval.key}-seconds">
        <span class="text-muted">Sec</span>
        <input
          id="interval-{interval.key}-seconds"
          class={inputClass}
          inputmode="numeric"
          autocomplete="off"
          value={interval.seconds}
          oninput={(event) => onedit("seconds", text(event))}
        />
      </label>
    </div>
  </div>
  <label class="grid gap-2" for="interval-{interval.key}-recovery">
    <span class="text-muted">Recovery (sec)</span>
    <input
      id="interval-{interval.key}-recovery"
      class={inputClass}
      inputmode="numeric"
      autocomplete="off"
      placeholder="None"
      aria-label="Recovery between repeats, in seconds. Leave empty for none."
      value={interval.recovery}
      oninput={(event) => onedit("recovery", text(event))}
    />
  </label>
  {#if readout}
    <p class="font-mono text-muted tabular-nums">{readout}</p>
  {/if}
  <BlockActions key={interval.key} noun="interval" {index} {total} {onmove} {onremove} />
</section>
