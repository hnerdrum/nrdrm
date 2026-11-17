<script lang="ts">
  import { STEADY_NAMES, type DraftSteady } from "../draft";
  import BlockActions from "./BlockActions.svelte";

  type Field = "name" | "kilometres" | "minutes" | "seconds";

  type Props = {
    steady: DraftSteady;
    index: number;
    total: number;
    onedit: (field: Field, value: string) => void;
    onmove: (direction: -1 | 1) => void;
    onremove: () => void;
  };

  let { steady, index, total, onedit, onmove, onremove }: Props = $props();

  const inputClass =
    "min-h-[52px] w-full min-w-0 rounded-2xl border border-edge bg-bg px-4 transition-[border-color] hover:border-muted focus-visible:border-accent focus-visible:outline-offset-1";

  const title = $derived(steady.name.trim() || "Steady");

  function text(event: Event): string {
    const target = event.currentTarget;
    return target instanceof HTMLInputElement ? target.value : "";
  }
</script>

<section class="grid gap-5 rounded-3xl border border-line bg-field p-5" aria-label="{title}, block {index + 1}">
  <h2 class="text-lg font-medium first-letter:uppercase">{title}</h2>
  <div class="grid gap-2">
    <label class="grid gap-2" for="steady-{steady.key}-name">
      <span class="text-muted">Name</span>
      <input
        id="steady-{steady.key}-name"
        class={inputClass}
        autocomplete="off"
        placeholder="Optional, such as tempo"
        value={steady.name}
        oninput={(event) => onedit("name", text(event))}
      />
    </label>
    <div class="flex flex-wrap gap-2">
      {#each STEADY_NAMES as name (name)}
        <button
          type="button"
          class="min-h-11 rounded-full border px-4 {steady.name.trim() === name
            ? 'border-accent bg-accent font-semibold text-on-accent'
            : 'border-edge text-muted hover:border-muted'}"
          aria-pressed={steady.name.trim() === name}
          onclick={() => onedit("name", steady.name.trim() === name ? "" : name)}
        >
          {name}
        </button>
      {/each}
    </div>
  </div>
  <label class="grid gap-2" for="steady-{steady.key}-km">
    <span class="text-muted">Distance (km)</span>
    <input
      id="steady-{steady.key}-km"
      class="{inputClass} font-mono text-lg tabular-nums"
      inputmode="decimal"
      autocomplete="off"
      placeholder="Optional"
      value={steady.kilometres}
      oninput={(event) => onedit("kilometres", text(event))}
    />
  </label>
  <div class="grid grid-cols-2 gap-4">
    <label class="grid gap-2" for="steady-{steady.key}-minutes">
      <span class="text-muted">Min</span>
      <input
        id="steady-{steady.key}-minutes"
        class="{inputClass} font-mono text-lg tabular-nums"
        inputmode="numeric"
        autocomplete="off"
        value={steady.minutes}
        oninput={(event) => onedit("minutes", text(event))}
      />
    </label>
    <label class="grid gap-2" for="steady-{steady.key}-seconds">
      <span class="text-muted">Sec</span>
      <input
        id="steady-{steady.key}-seconds"
        class="{inputClass} font-mono text-lg tabular-nums"
        inputmode="numeric"
        autocomplete="off"
        value={steady.seconds}
        oninput={(event) => onedit("seconds", text(event))}
      />
    </label>
  </div>
  <BlockActions key={steady.key} noun="part" {index} {total} {onmove} {onremove} />
</section>
