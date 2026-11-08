<script lang="ts">
  import { onMount, tick, untrack } from "svelte";
  import { createMutation, createQuery } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import {
    createSession,
    deleteSession,
    latestSession,
    sessionsQueryKey,
    updateSession,
    type LoggedSession,
  } from "../api/sessions";
  import { formatDay } from "../dates";
  import type { SessionBody } from "../domain";
  import {
    distanceBody,
    distanceDraft,
    emptyExercise,
    emptyInterval,
    exercisesFrom,
    intervalBody,
    intervalsFrom,
    strengthBody,
    type DraftExercise,
    type DraftInterval,
    type EffortKind,
  } from "../draft";
  import { sportLabel } from "../format";
  import Button from "./Button.svelte";
  import DistanceEditor from "./DistanceEditor.svelte";
  import SportPicker from "./SportPicker.svelte";
  import StrengthEditor from "./StrengthEditor.svelte";
  import TextField from "./TextField.svelte";

  type Props = {
    today: string;
    session?: LoggedSession | null;
    oncancel: () => void;
    onsaved: (onDate: string) => void;
    ondeleted?: () => void;
  };

  let { today, session = null, oncancel, onsaved, ondeleted }: Props = $props();

  const editing = untrack(() => session);
  const seeded = untrack(() =>
    editing && editing.body.sport !== "strength" ? distanceDraft(editing.body) : null,
  );

  let sport = $state<SessionBody["sport"]>(editing?.body.sport ?? "run");
  let date = $state(editing?.onDate ?? untrack(() => today));
  let kilometres = $state(seeded?.kilometres ?? "");
  let hours = $state(seeded?.hours ?? "");
  let minutes = $state(seeded?.minutes ?? "");
  let kind = $state<EffortKind>(
    editing && editing.body.sport !== "strength" && editing.body.intervals?.length
      ? "intervals"
      : "distance",
  );
  let intervals = $state<DraftInterval[]>(
    editing && editing.body.sport !== "strength" && editing.body.intervals?.length
      ? intervalsFrom(editing.body.intervals)
      : [emptyInterval()],
  );
  let exercises = $state<DraftExercise[]>(
    editing?.body.sport === "strength" ? exercisesFrom(editing.body) : [],
  );
  let prefilledFrom = $state<string | null>(null);
  let error = $state("");
  let confirming = $state(false);
  let applied = untrack(() => editing != null);

  const latest = createQuery(() => ({
    queryKey: [...sessionsQueryKey, "latest", "strength", today],
    queryFn: () => latestSession("strength", today),
    enabled: editing == null,
  }));

  const save = createMutation(() => ({
    mutationFn: (input: { onDate: string; body: SessionBody }) =>
      editing
        ? updateSession(editing.id, input.onDate, input.body)
        : createSession(input.onDate, input.body),
    onSuccess: (_saved, input) => onsaved(input.onDate),
  }));

  const remove = createMutation(() => ({
    mutationFn: () => {
      if (!editing) {
        return Promise.reject(new Error("No session"));
      }
      return deleteSession(editing.id);
    },
    onSuccess: () => ondeleted?.(),
  }));

  const waitingForLast = $derived(editing == null && sport === "strength" && latest.isPending);
  const loadError = $derived(
    latest.isError && !isUnauthorized(latest.error)
      ? "Couldn't load your last strength session."
      : "",
  );
  const saveError = $derived(
    save.isError && !isUnauthorized(save.error) ? "Couldn't save. Try again." : "",
  );
  const deleteError = $derived(
    remove.isError && !isUnauthorized(remove.error) ? "Couldn't delete. Try again." : "",
  );
  const deleteWhat = $derived(
    editing?.body.sport === "strength"
      ? "strength session"
      : sportLabel(editing?.body.sport ?? "run").toLowerCase(),
  );

  onMount(() => {
    window.scrollTo(0, 0);
  });

  $effect(() => {
    if (editing || applied || latest.isPending) {
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
    if (remove.isError) {
      remove.reset();
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
    if (save.isPending || remove.isPending || confirming || waitingForLast) {
      return;
    }

    let body: SessionBody | null;
    if (sport === "strength") {
      body = strengthBody(exercises);
      if (!body) {
        error = "Name each exercise. Enter reps or a time for every set.";
        return;
      }
    } else if (kind === "intervals") {
      body = intervalBody(sport, intervals);
      if (!body) {
        error = "Enter repeats, and metres or a time, for every interval.";
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

  async function askDelete() {
    if (remove.isPending) {
      return;
    }
    confirming = true;
    await tick();
    document.getElementById("delete-keep")?.focus();
  }

  async function keepSession() {
    confirming = false;
    if (remove.isError) {
      remove.reset();
    }
    await tick();
    document.getElementById("delete-session")?.focus();
  }

  function confirmDelete() {
    if (!editing || remove.isPending) {
      return;
    }
    remove.mutate();
  }
</script>

<div class="mx-auto flex min-h-dvh max-w-lg flex-col">
  <header class="-ml-3 pt-3">
    <Button variant="quiet" onclick={oncancel}>Cancel</Button>
  </header>
  <form
    class="form-enter flex flex-1 flex-col gap-7 pt-4"
    novalidate
    aria-busy={waitingForLast}
    oninput={clearError}
    onsubmit={submit}
  >
    <h1 class="text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
      {editing ? "Edit session" : "New session"}
    </h1>
    <SportPicker bind:sport locked={editing != null} />
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
      {#if waitingForLast}
        <p class="text-muted" role="status">Loading exercises…</p>
      {:else}
        {#if loadError}
          <p class="text-muted" role="status">{loadError}</p>
        {/if}
        <StrengthEditor {exercises} {prefilledFrom} onchange={(next) => (exercises = next)} />
      {/if}
    {:else}
      <DistanceEditor
        {sport}
        bind:kind
        bind:kilometres
        bind:hours
        bind:minutes
        {intervals}
        onchange={(next) => (intervals = next)}
      />
    {/if}
    {#if editing}
      {#if confirming}
        <div
          class="grid gap-3 rounded-3xl border border-edge bg-field p-5"
          role="group"
          aria-labelledby="delete-question"
        >
          <p id="delete-question" class="text-lg font-medium">
            Delete the {deleteWhat} from {formatDay(editing.onDate)}?
          </p>
          {#if deleteError}
            <p class="font-medium" role="alert">{deleteError}</p>
          {/if}
          <div class="flex flex-wrap gap-2">
            <Button variant="outline" disabled={remove.isPending} onclick={confirmDelete}>
              Delete
            </Button>
            <Button id="delete-keep" variant="quiet" disabled={remove.isPending} onclick={keepSession}>
              Keep
            </Button>
          </div>
        </div>
      {:else}
        <div class="-ml-3">
          <Button id="delete-session" variant="quiet" onclick={askDelete}>Delete session</Button>
        </div>
      {/if}
    {/if}
    <div
      class="sticky bottom-0 z-10 mt-auto grid gap-2 border-t border-line bg-[rgba(19,18,28,0.82)] pt-3.5 pb-[calc(0.875rem+env(safe-area-inset-bottom,0px))] backdrop-blur-lg"
    >
      {#if error || saveError}
        <p class="font-medium" role="alert">{error || saveError}</p>
      {/if}
      <Button type="submit" variant="accent" class="w-full" disabled={waitingForLast || confirming || remove.isPending}>
        Save
      </Button>
    </div>
  </form>
</div>
