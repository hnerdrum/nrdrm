<script lang="ts">
  import type { DraftExercise, SetMeasure } from "../draft";
  import Button from "./Button.svelte";

  type Props = {
    exercise: DraftExercise;
    index: number;
    total: number;
    onname: (name: string) => void;
    onmeasure: (measure: SetMeasure) => void;
    onset: (setKey: string, field: "reps" | "weight" | "minutes" | "seconds", value: string) => void;
    onaddset: () => void;
    onremoveset: (setKey: string) => void;
    onmove: (direction: -1 | 1) => void;
    onremove: () => void;
  };

  let {
    exercise,
    index,
    total,
    onname,
    onmeasure,
    onset,
    onaddset,
    onremoveset,
    onmove,
    onremove,
  }: Props = $props();

  const inputClass =
    "min-h-[52px] w-full min-w-0 rounded-2xl border border-edge bg-bg px-4 transition-[border-color] hover:border-muted focus-visible:border-accent focus-visible:outline-offset-1";

  function text(event: Event): string {
    const target = event.currentTarget;
    return target instanceof HTMLInputElement ? target.value : "";
  }
</script>

<section
  class="grid gap-5 rounded-3xl border border-line bg-field p-5"
  aria-label="Exercise {index + 1}"
>
  <label class="grid gap-2" for="exercise-{exercise.key}-name">
    <span class="text-muted">Exercise {index + 1}</span>
    <input
      id="exercise-{exercise.key}-name"
      class={inputClass}
      autocomplete="off"
      value={exercise.name}
      oninput={(event) => onname(text(event))}
    />
  </label>
  <fieldset class="m-0 grid gap-2 border-0 p-0">
    <legend class="p-0 text-muted">Sets</legend>
    <div class="flex gap-2">
      <label class="relative min-w-24">
        <input
          class="peer absolute inset-0 m-0 cursor-pointer opacity-0 focus-visible:outline-none"
          type="radio"
          name="measure-{exercise.key}"
          value="reps"
          checked={exercise.measure === "reps"}
          onchange={() => onmeasure("reps")}
        />
        <span
          class="flex min-h-11 items-center justify-center rounded-full border border-edge px-4 text-muted peer-checked:border-accent peer-checked:bg-accent peer-checked:font-semibold peer-checked:text-on-accent peer-focus-visible:outline peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent"
        >
          Reps
        </span>
      </label>
      <label class="relative min-w-24">
        <input
          class="peer absolute inset-0 m-0 cursor-pointer opacity-0 focus-visible:outline-none"
          type="radio"
          name="measure-{exercise.key}"
          value="time"
          checked={exercise.measure === "time"}
          onchange={() => onmeasure("time")}
        />
        <span
          class="flex min-h-11 items-center justify-center rounded-full border border-edge px-4 text-muted peer-checked:border-accent peer-checked:bg-accent peer-checked:font-semibold peer-checked:text-on-accent peer-focus-visible:outline peer-focus-visible:outline-offset-2 peer-focus-visible:outline-accent"
        >
          Time
        </span>
      </label>
    </div>
  </fieldset>
  <div class="grid gap-2">
    {#if exercise.measure === "reps"}
      <div
        class="grid grid-cols-[2rem_minmax(0,1fr)_minmax(0,1fr)_auto] items-center gap-2 text-muted"
        aria-hidden="true"
      >
        <span>Set</span>
        <span>Reps</span>
        <span>kg</span>
        <span></span>
      </div>
      {#each exercise.sets as set, setIndex (set.key)}
        <div class="grid grid-cols-[2rem_minmax(0,1fr)_minmax(0,1fr)_auto] items-center gap-2">
          <span class="font-mono text-muted">{setIndex + 1}</span>
          <input
            id="set-{set.key}-reps"
            class="{inputClass} font-mono text-lg tabular-nums"
            inputmode="numeric"
            autocomplete="off"
            aria-label="Exercise {index + 1} set {setIndex + 1} reps"
            value={set.reps}
            oninput={(event) => onset(set.key, "reps", text(event))}
          />
          <input
            id="set-{set.key}-kg"
            class="{inputClass} font-mono text-lg tabular-nums"
            inputmode="decimal"
            autocomplete="off"
            placeholder="Bodyweight"
            aria-label="Exercise {index + 1} set {setIndex + 1} weight in kg. Leave empty for bodyweight."
            value={set.weight}
            oninput={(event) => onset(set.key, "weight", text(event))}
          />
          <Button
            variant="quiet"
            class="px-0"
            label="Remove set {setIndex + 1} of exercise {index + 1}"
            disabled={exercise.sets.length < 2}
            onclick={() => onremoveset(set.key)}
          >
            Remove
          </Button>
        </div>
      {/each}
    {:else}
      <div
        class="grid grid-cols-[2rem_minmax(0,1fr)_minmax(0,1fr)_auto] items-center gap-2 text-muted"
        aria-hidden="true"
      >
        <span>Set</span>
        <span>Min</span>
        <span>Sec</span>
        <span></span>
      </div>
      {#each exercise.sets as set, setIndex (set.key)}
        <div class="grid grid-cols-[2rem_minmax(0,1fr)_minmax(0,1fr)_auto] items-center gap-2">
          <span class="font-mono text-muted">{setIndex + 1}</span>
          <input
            id="set-{set.key}-minutes"
            class="{inputClass} font-mono text-lg tabular-nums"
            inputmode="numeric"
            autocomplete="off"
            aria-label="Exercise {index + 1} set {setIndex + 1} minutes"
            value={set.minutes}
            oninput={(event) => onset(set.key, "minutes", text(event))}
          />
          <input
            id="set-{set.key}-seconds"
            class="{inputClass} font-mono text-lg tabular-nums"
            inputmode="numeric"
            autocomplete="off"
            aria-label="Exercise {index + 1} set {setIndex + 1} seconds"
            value={set.seconds}
            oninput={(event) => onset(set.key, "seconds", text(event))}
          />
          <Button
            variant="quiet"
            class="px-0"
            label="Remove set {setIndex + 1} of exercise {index + 1}"
            disabled={exercise.sets.length < 2}
            onclick={() => onremoveset(set.key)}
          >
            Remove
          </Button>
        </div>
      {/each}
    {/if}
  </div>
  <div class="-ml-2 flex flex-wrap gap-x-1">
    <Button id="add-set-{exercise.key}" variant="quiet" onclick={onaddset}>Add set</Button>
    <Button
      id="move-up-{exercise.key}"
      variant="quiet"
      disabled={index === 0}
      onclick={() => onmove(-1)}
    >
      Move up
    </Button>
    <Button
      id="move-down-{exercise.key}"
      variant="quiet"
      disabled={index === total - 1}
      onclick={() => onmove(1)}
    >
      Move down
    </Button>
    <Button variant="quiet" disabled={total < 2} onclick={onremove}>Remove exercise</Button>
  </div>
</section>
