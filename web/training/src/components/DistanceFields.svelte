<script lang="ts">
  import { derivedEffort, type DistanceSport } from "../draft";
  import TextField from "./TextField.svelte";

  type Props = {
    sport: DistanceSport;
    kilometres?: string;
    hours?: string;
    minutes?: string;
  };

  let {
    sport,
    kilometres = $bindable(""),
    hours = $bindable(""),
    minutes = $bindable(""),
  }: Props = $props();

  const readout = $derived(derivedEffort(sport, kilometres, hours, minutes));
</script>

<div class="rise-in grid gap-7">
  <TextField
    id="distance"
    label="Distance (km)"
    inputmode="decimal"
    autocomplete="off"
    large
    mono
    bind:value={kilometres}
  />
  <div class="grid grid-cols-2 gap-4">
    <TextField
      id="hours"
      label="Hours"
      inputmode="numeric"
      autocomplete="off"
      large
      mono
      bind:value={hours}
    />
    <TextField
      id="minutes"
      label="Minutes"
      inputmode="numeric"
      autocomplete="off"
      large
      mono
      bind:value={minutes}
    />
  </div>
  {#if readout}
    <div
      class="derived-enter flex items-baseline justify-between gap-4 border-y border-line px-1 py-5"
    >
      <span class="text-base font-medium tracking-[0.16em] text-muted uppercase"
        >{readout.label}</span
      >
      <b
        class="font-mono text-[2.75rem] leading-none font-light tracking-[-0.06em] tabular-nums"
        >{readout.value}</b
      >
    </div>
  {/if}
</div>
