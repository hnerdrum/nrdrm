<script lang="ts">
  import { onMount, untrack } from "svelte";
  import type { SessionBody } from "../domain";
  import {
    distanceBody,
    emptyExercise,
    exercisesFrom,
    strengthBody,
    type DraftExercise,
  } from "../draft";
  import { createSession, latestSession } from "../log";
  import Button from "./Button.svelte";
  import DistanceFields from "./DistanceFields.svelte";
  import SportPicker from "./SportPicker.svelte";
  import StrengthEditor from "./StrengthEditor.svelte";
  import TextField from "./TextField.svelte";

  type Props = {
    today: string;
    oncancel: () => void;
    onsaved: (onDate: string) => void;
    onsignedout: () => void;
  };

  let { today, oncancel, onsaved, onsignedout }: Props = $props();

  let sport = $state<SessionBody["sport"]>("run");
  let date = $state(untrack(() => today));
  let kilometres = $state("");
  let hours = $state("");
  let minutes = $state("");
  let exercises = $state<DraftExercise[]>([]);
  let prefilledFrom = $state<string | null>(null);
  let strengthReady = $state(false);
  let loadError = $state("");
  let error = $state("");
  let saving = $state(false);

  onMount(() => {
    window.scrollTo(0, 0);
  });

  $effect(() => {
    if (strengthReady) return;
    const through = today;
    let cancelled = false;
    latestSession("strength", through)
      .then((result) => {
        if (cancelled) return;
        if (result === "unauthorized") {
          onsignedout();
          return;
        }
        if (result?.body.sport === "strength" && result.body.exercises.length > 0) {
          exercises = exercisesFrom(result.body);
          prefilledFrom = result.onDate;
        } else {
          exercises = [emptyExercise()];
        }
        strengthReady = true;
      })
      .catch(() => {
        if (cancelled) return;
        exercises = [emptyExercise()];
        loadError = "Couldn't load your last strength session.";
        strengthReady = true;
      });
    return () => {
      cancelled = true;
    };
  });

  function clearError() {
    error = "";
  }

  function acceptableDate(value: string): boolean {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value > today) return false;
    const [year, month, day] = value.split("-").map(Number);
    const parsed = new Date(Date.UTC(year, month - 1, day));
    return (
      parsed.getUTCFullYear() === year &&
      parsed.getUTCMonth() === month - 1 &&
      parsed.getUTCDate() === day
    );
  }

  async function submit(event: SubmitEvent) {
    event.preventDefault();
    if (saving || (sport === "strength" && !strengthReady)) return;

    let body: SessionBody | null;
    if (sport === "strength") {
      body = strengthBody(exercises);
      if (!body) {
        error = "Name each exercise and fill reps and kg for every set.";
        return;
      }
    } else {
      body = distanceBody(sport, kilometres, hours, minutes);
      if (!body) {
        error = "Enter a distance and a time.";
        return;
      }
    }
    if (!acceptableDate(date)) {
      error = "Pick a date.";
      return;
    }

    saving = true;
    const result = await createSession(date, body);
    saving = false;
    if (result === "ok") {
      onsaved(date);
      return;
    }
    if (result === "unauthorized") {
      onsignedout();
      return;
    }
    error = "Couldn't save. Try again.";
  }
</script>

<div class="mx-auto flex min-h-dvh max-w-lg flex-col">
  <header class="-ml-3 pt-3">
    <Button variant="quiet" onclick={oncancel}>Cancel</Button>
  </header>
  <form
    class="form-enter flex flex-1 flex-col gap-7 pt-4"
    novalidate
    aria-busy={sport === "strength" && !strengthReady}
    oninput={clearError}
    onsubmit={submit}
  >
    <h1 class="text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
      New session
    </h1>
    <SportPicker bind:sport />
    <TextField
      id="session-date"
      label="Date"
      type="date"
      max={today}
      autocomplete="off"
      mono
      bind:value={date}
    />
    {#if sport === "strength"}
      {#if strengthReady}
        {#if loadError}
          <p class="text-muted" role="status">{loadError}</p>
        {/if}
        <StrengthEditor {exercises} {prefilledFrom} onchange={(next) => (exercises = next)} />
      {:else}
        <p class="text-muted" role="status">Loading exercises…</p>
      {/if}
    {:else}
      <DistanceFields {sport} bind:kilometres bind:hours bind:minutes />
    {/if}
    <div
      class="sticky bottom-0 z-10 mt-auto grid gap-2 border-t border-line bg-[rgba(19,18,28,0.82)] pt-3.5 pb-[calc(0.875rem+env(safe-area-inset-bottom,0px))] backdrop-blur-lg"
    >
      {#if error}
        <p class="font-medium" role="alert">{error}</p>
      {/if}
      <Button
        type="submit"
        variant="accent"
        class="w-full"
        disabled={sport === "strength" && !strengthReady}
      >
        Save
      </Button>
    </div>
  </form>
</div>
