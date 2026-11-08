<script lang="ts">
  import { onMount, untrack } from "svelte";
  import { createMutation, createQuery } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import { createSession, latestSession, sessionsQueryKey } from "../api/sessions";
  import type { SessionBody } from "../domain";
  import {
    distanceBody,
    emptyExercise,
    exercisesFrom,
    strengthBody,
    type DraftExercise,
  } from "../draft";
  import Button from "./Button.svelte";
  import DistanceFields from "./DistanceFields.svelte";
  import SportPicker from "./SportPicker.svelte";
  import StrengthEditor from "./StrengthEditor.svelte";
  import TextField from "./TextField.svelte";

  type Props = {
    today: string;
    oncancel: () => void;
    onsaved: (onDate: string) => void;
  };

  let { today, oncancel, onsaved }: Props = $props();

  let sport = $state<SessionBody["sport"]>("run");
  let date = $state(untrack(() => today));
  let kilometres = $state("");
  let hours = $state("");
  let minutes = $state("");
  let exercises = $state<DraftExercise[]>([]);
  let prefilledFrom = $state<string | null>(null);
  let error = $state("");
  let applied = false;

  const latest = createQuery(() => ({
    queryKey: [...sessionsQueryKey, "latest", "strength", today],
    queryFn: () => latestSession("strength", today),
  }));

  const save = createMutation(() => ({
    mutationFn: (input: { onDate: string; body: SessionBody }) =>
      createSession(input.onDate, input.body),
    onSuccess: (_saved, input) => onsaved(input.onDate),
  }));

  const loadError = $derived(
    latest.isError && !isUnauthorized(latest.error)
      ? "Couldn't load your last strength session."
      : "",
  );
  const saveError = $derived(
    save.isError && !isUnauthorized(save.error) ? "Couldn't save. Try again." : "",
  );

  onMount(() => {
    window.scrollTo(0, 0);
  });

  $effect(() => {
    if (applied || latest.isPending) {
      return;
    }
    applied = true;
    const result = latest.data;
    if (latest.isError || result == null || result.body.sport !== "strength") {
      exercises = [emptyExercise()];
      return;
    }
    if (result.body.exercises.length === 0) {
      exercises = [emptyExercise()];
      return;
    }
    exercises = exercisesFrom(result.body);
    prefilledFrom = result.onDate;
  });

  function clearError() {
    error = "";
    if (save.isError) {
      save.reset();
    }
  }

  function acceptableDate(value: string): boolean {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || value > today) {
      return false;
    }
    const [year, month, day] = value.split("-").map(Number);
    const parsed = new Date(Date.UTC(year, month - 1, day));
    return (
      parsed.getUTCFullYear() === year &&
      parsed.getUTCMonth() === month - 1 &&
      parsed.getUTCDate() === day
    );
  }

  function submit(event: SubmitEvent) {
    event.preventDefault();
    if (save.isPending || (sport === "strength" && latest.isPending)) {
      return;
    }

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

    save.mutate({ onDate: date, body });
  }
</script>

<div class="mx-auto flex min-h-dvh max-w-lg flex-col">
  <header class="-ml-3 pt-3">
    <Button variant="quiet" onclick={oncancel}>Cancel</Button>
  </header>
  <form
    class="form-enter flex flex-1 flex-col gap-7 pt-4"
    novalidate
    aria-busy={sport === "strength" && latest.isPending}
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
      {#if latest.isPending}
        <p class="text-muted" role="status">Loading exercises…</p>
      {:else}
        {#if loadError}
          <p class="text-muted" role="status">{loadError}</p>
        {/if}
        <StrengthEditor {exercises} {prefilledFrom} onchange={(next) => (exercises = next)} />
      {/if}
    {:else}
      <DistanceFields {sport} bind:kilometres bind:hours bind:minutes />
    {/if}
    <div
      class="sticky bottom-0 z-10 mt-auto grid gap-2 border-t border-line bg-[rgba(19,18,28,0.82)] pt-3.5 pb-[calc(0.875rem+env(safe-area-inset-bottom,0px))] backdrop-blur-lg"
    >
      {#if error || saveError}
        <p class="font-medium" role="alert">{error || saveError}</p>
      {/if}
      <Button
        type="submit"
        variant="accent"
        class="w-full"
        disabled={sport === "strength" && latest.isPending}
      >
        Save
      </Button>
    </div>
  </form>
</div>
