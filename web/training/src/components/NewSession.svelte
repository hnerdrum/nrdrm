<script lang="ts">
  import { onMount, tick, untrack } from "svelte";
  import { createMutation, createQuery } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import { listPresets, presetsQueryKey, type Preset } from "../api/presets";
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
  import { sportLabel } from "../format";
  import Button from "./Button.svelte";
  import PresetPicker from "./PresetPicker.svelte";
  import SaveAsPreset from "./SaveAsPreset.svelte";
  import SessionBodyEditor from "./SessionBodyEditor.svelte";
  import SportPicker from "./SportPicker.svelte";
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

  let editor = $state<ReturnType<typeof SessionBodyEditor>>();
  let presetSaver = $state<ReturnType<typeof SaveAsPreset>>();
  let sport = $state<SessionBody["sport"]>(editing?.body.sport ?? "run");
  let date = $state(editing?.onDate ?? untrack(() => today));
  let prefilledFrom = $state<string | null>(null);
  let picked = $state<Preset | null>(null);
  let error = $state("");
  let confirming = $state(false);
  let applied = untrack(() => editing != null);

  const latest = createQuery(() => ({
    queryKey: [...sessionsQueryKey, "latest", "strength", today],
    queryFn: () => latestSession("strength", today),
    enabled: editing == null,
  }));

  const presets = createQuery(() => ({
    queryKey: presetsQueryKey,
    queryFn: listPresets,
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

  /** A strength preset filled the exercises, so the last strength session
   * doesn't. */
  const pickedStrength = $derived(picked?.body.sport === "strength");
  const waitingForLast = $derived(
    editing == null && !pickedStrength && sport === "strength" && latest.isPending,
  );
  const loadError = $derived(
    !pickedStrength && latest.isError && !isUnauthorized(latest.error)
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
    if (editing || applied || latest.isPending || !editor) {
      return;
    }
    applied = true;
    const result = latest.data;
    if (
      latest.isError ||
      result == null ||
      result.body.sport !== "strength" ||
      result.body.exercises.length === 0
    ) {
      editor.seed({ sport: "strength", exercises: [] });
      return;
    }
    editor.seed(result.body);
    prefilledFrom = result.onDate;
  });

  /** Fill the form from a preset and switch to its sport. It replaces what
   * was there. After a strength preset, the last strength session no longer
   * fills the exercises, even if it loads later. */
  function pick(preset: Preset) {
    if (!editor) {
      return;
    }
    picked = preset;
    if (preset.body.sport === "strength") {
      applied = true;
      prefilledFrom = null;
    }
    editor.fill(preset.body);
    clearError();
  }

  function clearError() {
    error = "";
    presetSaver?.clearError();
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

    const body = editor?.build();
    if (body === undefined) {
      return;
    }
    if (typeof body === "string") {
      error = body;
      return;
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
    {#if !editing && presets.data && presets.data.length > 0}
      <PresetPicker presets={presets.data} {picked} onpick={pick} />
    {/if}
    <SportPicker bind:sport locked={editing != null} />
    {#if picked && picked.body.sport === sport}
      <p class="-mt-3 text-muted" role="status">
        From {picked.name}. Change what you need.
      </p>
    {/if}
    <TextField
      id="session-date"
      label="Date"
      type="date"
      max={today}
      autocomplete="off"
      mono
      bind:value={date}
    />
    <SessionBodyEditor
      bind:this={editor}
      bind:sport
      initial={editing?.body ?? null}
      loadingExercises={waitingForLast}
      exercisesNote={loadError}
      {prefilledFrom}
    />
    {#if editing}
      {#if !confirming}
        <SaveAsPreset
          bind:this={presetSaver}
          build={() => editor?.build() ?? "The form isn't ready yet."}
        />
      {/if}
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
