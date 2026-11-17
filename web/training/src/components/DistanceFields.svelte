<script lang="ts">
  import { derivedEffort, type DistanceSport } from "../draft";
  import TextField from "./TextField.svelte";

  type Props = {
    sport: DistanceSport;
    kilometres?: string;
    hours?: string;
    minutes?: string;
    /** What a blank field stands for: the blocks' totals. */
    blank?: { kilometres: string; hours: string; minutes: string } | null;
  };

  let {
    sport,
    kilometres = $bindable(""),
    hours = $bindable(""),
    minutes = $bindable(""),
    blank = null,
  }: Props = $props();

  const timeBlank = $derived(hours.trim() === "" && minutes.trim() === "");
  const readout = $derived(
    derivedEffort(
      sport,
      kilometres.trim() === "" && blank ? blank.kilometres : kilometres,
      timeBlank && blank ? blank.hours : hours,
      timeBlank && blank ? blank.minutes : minutes,
    ),
  );
</script>

<div class="rise-in grid gap-7">
  <TextField
    id="distance"
    label="Distance (km)"
    inputmode="decimal"
    placeholder={blank?.kilometres}
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
      placeholder={timeBlank ? blank?.hours : undefined}
      autocomplete="off"
      large
      mono
      bind:value={hours}
    />
    <TextField
      id="minutes"
      label="Minutes"
      inputmode="numeric"
      placeholder={timeBlank ? blank?.minutes : undefined}
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
