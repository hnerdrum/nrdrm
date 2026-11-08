<script lang="ts">
  import type { DraftExercise } from "../draft";
  import Button from "./Button.svelte";

  type Props = {
    exercise: DraftExercise;
    index: number;
    total: number;
    onname: (name: string) => void;
    onset: (setKey: string, field: "reps" | "weight", value: string) => void;
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
  <div class="grid gap-2">
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
          aria-label="Exercise {index + 1} set {setIndex + 1} weight in kg"
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
