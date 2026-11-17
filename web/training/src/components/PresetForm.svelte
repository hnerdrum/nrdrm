<script lang="ts">
  import { onMount, tick, untrack } from "svelte";
  import { createMutation } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import {
    createPreset,
    deletePreset,
    isNameTaken,
    presetNameProblem,
    updatePreset,
    type Preset,
  } from "../api/presets";
  import type { SessionBody } from "../domain";
  import Button from "./Button.svelte";
  import SessionBodyEditor from "./SessionBodyEditor.svelte";
  import SportPicker from "./SportPicker.svelte";
  import TextField from "./TextField.svelte";

  type Props = {
    preset?: Preset | null;
    oncancel: () => void;
    onsaved: () => void;
    ondeleted?: () => void;
  };

  let { preset = null, oncancel, onsaved, ondeleted }: Props = $props();

  const editing = untrack(() => preset);

  let editor = $state<ReturnType<typeof SessionBodyEditor>>();
  let name = $state(editing?.name ?? "");
  let sport = $state<SessionBody["sport"]>(editing?.body.sport ?? "strength");
  let error = $state("");
  let confirming = $state(false);

  const save = createMutation(() => ({
    mutationFn: (input: { name: string; body: SessionBody }) =>
      editing
        ? updatePreset(editing.id, input.name, input.body)
        : createPreset(input.name, input.body),
    onSuccess: () => onsaved(),
  }));

  const remove = createMutation(() => ({
    mutationFn: () => {
      if (!editing) {
        return Promise.reject(new Error("No preset"));
      }
      return deletePreset(editing.id);
    },
    onSuccess: () => ondeleted?.(),
  }));

  const saveError = $derived.by(() => {
    if (!save.isError || isUnauthorized(save.error)) {
      return "";
    }
    if (isNameTaken(save.error)) {
      return "You already have a preset with that name.";
    }
    return "Couldn't save. Try again.";
  });
  const deleteError = $derived(
    remove.isError && !isUnauthorized(remove.error) ? "Couldn't delete. Try again." : "",
  );

  onMount(() => {
    window.scrollTo(0, 0);
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

  function submit(event: SubmitEvent) {
    event.preventDefault();
    if (save.isPending || remove.isPending || confirming || !editor) {
      return;
    }
    const nameProblem = presetNameProblem(name);
    if (nameProblem) {
      error = nameProblem;
      return;
    }
    const body = editor.build();
    if (typeof body === "string") {
      error = body;
      return;
    }
    save.mutate({ name: name.trim(), body });
  }

  async function askDelete() {
    if (remove.isPending) {
      return;
    }
    confirming = true;
    await tick();
    document.getElementById("delete-keep")?.focus();
  }

  async function keepPreset() {
    confirming = false;
    if (remove.isError) {
      remove.reset();
    }
    await tick();
    document.getElementById("delete-preset")?.focus();
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
    oninput={clearError}
    onsubmit={submit}
  >
    <h1 class="text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
      {editing ? "Edit preset" : "New preset"}
    </h1>
    <TextField id="preset-name" label="Name" autocomplete="off" bind:value={name} />
    <SportPicker bind:sport />
    <SessionBodyEditor bind:this={editor} bind:sport initial={editing?.body ?? null} />
    {#if editing}
      {#if confirming}
        <div
          class="grid gap-3 rounded-3xl border border-edge bg-field p-5"
          role="group"
          aria-labelledby="delete-question"
        >
          <p id="delete-question" class="text-lg font-medium">
            Delete the preset “{editing.name}”?
          </p>
          <p class="text-muted">Sessions you logged from it stay as they are.</p>
          {#if deleteError}
            <p class="font-medium" role="alert">{deleteError}</p>
          {/if}
          <div class="flex flex-wrap gap-2">
            <Button variant="outline" disabled={remove.isPending} onclick={confirmDelete}>
              Delete
            </Button>
            <Button id="delete-keep" variant="quiet" disabled={remove.isPending} onclick={keepPreset}>
              Keep
            </Button>
          </div>
        </div>
      {:else}
        <div class="-ml-3">
          <Button id="delete-preset" variant="quiet" onclick={askDelete}>Delete preset</Button>
        </div>
      {/if}
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
        disabled={confirming || remove.isPending}
      >
        Save
      </Button>
    </div>
  </form>
</div>
