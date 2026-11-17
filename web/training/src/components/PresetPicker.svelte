<script lang="ts">
  import type { Preset } from "../api/presets";
  import { sportLabel } from "../format";

  type Props = {
    presets: Preset[];
    /** The preset that filled the form, if any. */
    picked: Preset | null;
    onpick: (preset: Preset) => void;
  };

  let { presets, picked, onpick }: Props = $props();
</script>

<div class="grid gap-2" role="group" aria-labelledby="preset-picker-label">
  <span id="preset-picker-label" class="text-muted">Start from a preset</span>
  <ul class="m-0 flex list-none flex-wrap gap-2 p-0">
    {#each presets as preset (preset.id)}
      {@const chosen = picked?.id === preset.id}
      <li>
        <button
          type="button"
          class="inline-flex min-h-11 cursor-pointer items-baseline gap-2 rounded-full border px-4 py-2 text-left transition-colors {chosen
            ? 'border-accent bg-accent font-semibold text-on-accent'
            : 'border-edge bg-field hover:border-muted'}"
          aria-pressed={chosen}
          onclick={() => onpick(preset)}
        >
          {preset.name}
          <span class="text-sm {chosen ? 'text-on-accent/75' : 'text-muted'}">
            {sportLabel(preset.body.sport)}
          </span>
        </button>
      </li>
    {/each}
  </ul>
</div>
