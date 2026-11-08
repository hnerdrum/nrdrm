<script lang="ts">
  import { tick } from "svelte";
  import {
    emptyInterval,
    intervalBody,
    intervalPace,
    type DraftInterval,
    type RunKind,
  } from "../draft";
  import { formatDuration, formatKm } from "../format";
  import Button from "./Button.svelte";
  import DistanceFields from "./DistanceFields.svelte";

  type IntervalField = "repetitions" | "metres" | "minutes" | "seconds" | "recovery";

  type Props = {
    kind?: RunKind;
    kilometres?: string;
    hours?: string;
    minutes?: string;
    intervals: DraftInterval[];
    onchange: (intervals: DraftInterval[]) => void;
  };

  let {
    kind = $bindable("distance"),
    kilometres = $bindable(""),
    hours = $bindable(""),
    minutes = $bindable(""),
    intervals,
    onchange,
  }: Props = $props();

  const inputClass =
    "min-h-[52px] w-full min-w-0 rounded-2xl border border-edge bg-bg px-4 font-mono text-lg tabular-nums transition-[border-color] hover:border-muted focus-visible:border-accent focus-visible:outline-offset-1";

  const summary = $derived.by(() => {
    const body = intervalBody(intervals);
    if (!body) {
      return null;
    }
    return `${formatKm(body.distance)} · ${formatDuration(body.duration)}`;
  });

  function text(event: Event): string {
    const target = event.currentTarget;
    return target instanceof HTMLInputElement ? target.value : "";
  }

  async function focus(id: string) {
    await tick();
    document.getElementById(id)?.focus();
  }

  function edit(key: string, field: IntervalField, value: string) {
    onchange(
      intervals.map((interval) =>
        interval.key === key ? { ...interval, [field]: value } : interval,
      ),
    );
  }

  function addInterval() {
    const created = emptyInterval();
    onchange([...intervals, created]);
    void focus(`interval-${created.key}-repeats`);
  }

  function removeInterval(key: string) {
    if (intervals.length < 2) {
      return;
    }
    onchange(intervals.filter((interval) => interval.key !== key));
    void focus("add-interval");
  }

  function move(key: string, direction: -1 | 1) {
    const index = intervals.findIndex((interval) => interval.key === key);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= intervals.length) {
      return;
    }
    const next = intervals.slice();
    const [item] = next.splice(index, 1);
    next.splice(target, 0, item);
    onchange(next);
  }
</script>

<div class="grid gap-7">
  <fieldset class="m-0 grid gap-2 border-0 p-0">
    <legend class="p-0 text-muted">Run</legend>
    <div class="flex gap-2">
      <label class="relative min-w-28">
        <input
          class="peer absolute inset-0 m-0 cursor-pointer opacity-0 focus-visible:outline-none"
          type="radio"
          name="run-kind"
          value="distance"
          checked={kind === "distance"}
          onchange={() => (kind = "distance")}
        />
        <span
          class="flex min-h-11 items-center justify-center rounded-full border border-edge px-4 text-muted peer-checked:border-accent peer-checked:bg-accent peer-checked:font-semibold peer-checked:text-on-accent peer-focus-visible:outline peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent"
        >
          Distance
        </span>
      </label>
      <label class="relative min-w-28">
        <input
          class="peer absolute inset-0 m-0 cursor-pointer opacity-0 focus-visible:outline-none"
          type="radio"
          name="run-kind"
          value="intervals"
          checked={kind === "intervals"}
          onchange={() => (kind = "intervals")}
        />
        <span
          class="flex min-h-11 items-center justify-center rounded-full border border-edge px-4 text-muted peer-checked:border-accent peer-checked:bg-accent peer-checked:font-semibold peer-checked:text-on-accent peer-focus-visible:outline peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent"
        >
          Intervals
        </span>
      </label>
    </div>
  </fieldset>
  {#if kind === "distance"}
    <DistanceFields sport="run" bind:kilometres bind:hours bind:minutes />
  {:else}
    <div class="rise-in grid gap-7">
      {#each intervals as interval, index (interval.key)}
        {@const pace = intervalPace(interval)}
        <section class="grid gap-5 rounded-3xl border border-line bg-field p-5" aria-label="Interval {index + 1}">
          <h2 class="text-lg font-medium">Interval {index + 1}</h2>
          <div class="grid grid-cols-2 gap-4">
            <label class="grid gap-2" for="interval-{interval.key}-repeats">
              <span class="text-muted">Repeats</span>
              <input
                id="interval-{interval.key}-repeats"
                class={inputClass}
                inputmode="numeric"
                autocomplete="off"
                value={interval.repetitions}
                oninput={(event) => edit(interval.key, "repetitions", text(event))}
              />
            </label>
            <label class="grid gap-2" for="interval-{interval.key}-metres">
              <span class="text-muted">Metres</span>
              <input
                id="interval-{interval.key}-metres"
                class={inputClass}
                inputmode="numeric"
                autocomplete="off"
                value={interval.metres}
                oninput={(event) => edit(interval.key, "metres", text(event))}
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
                  oninput={(event) => edit(interval.key, "minutes", text(event))}
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
                  oninput={(event) => edit(interval.key, "seconds", text(event))}
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
              oninput={(event) => edit(interval.key, "recovery", text(event))}
            />
          </label>
          {#if pace}
            <p class="font-mono text-muted tabular-nums">{pace}</p>
          {/if}
          <div class="-ml-2 flex flex-wrap gap-x-1">
            <Button
              variant="quiet"
              disabled={index === 0}
              onclick={() => move(interval.key, -1)}
            >
              Move up
            </Button>
            <Button
              variant="quiet"
              disabled={index === intervals.length - 1}
              onclick={() => move(interval.key, 1)}
            >
              Move down
            </Button>
            <Button variant="quiet" disabled={intervals.length < 2} onclick={() => removeInterval(interval.key)}>
              Remove
            </Button>
          </div>
        </section>
      {/each}
      {#if summary}
        <p class="font-mono text-muted tabular-nums">{summary}</p>
      {/if}
      <div>
        <Button id="add-interval" variant="outline" onclick={addInterval}>Add interval</Button>
      </div>
    </div>
  {/if}
</div>
