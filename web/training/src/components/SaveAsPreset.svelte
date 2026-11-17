<script lang="ts">
  import { tick } from "svelte";
  import { createMutation, useQueryClient } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import {
    createPreset,
    isNameTaken,
    presetNameProblem,
    presetsQueryKey,
  } from "../api/presets";
  import type { SessionBody } from "../domain";
  import Button from "./Button.svelte";
  import TextField from "./TextField.svelte";

  type Props = {
    /** The body the form shows now, or what to fix first. */
    build: () => SessionBody | string;
  };

  let { build }: Props = $props();

  const queryClient = useQueryClient();

  let naming = $state(false);
  let name = $state("");
  let error = $state("");
  let savedAs = $state<string | null>(null);

  const save = createMutation(() => ({
    mutationFn: (input: { name: string; body: SessionBody }) =>
      createPreset(input.name, input.body),
    onSuccess: async (preset) => {
      void queryClient.invalidateQueries({ queryKey: presetsQueryKey });
      savedAs = preset.name;
      naming = false;
      name = "";
      await tick();
      document.getElementById("save-as-preset")?.focus();
    },
  }));

  const saveError = $derived.by(() => {
    if (!save.isError || isUnauthorized(save.error)) {
      return "";
    }
    if (isNameTaken(save.error)) {
      return "You already have a preset with that name.";
    }
    return "Couldn't save the preset. Try again.";
  });

  async function open() {
    naming = true;
    savedAs = null;
    await tick();
    document.getElementById("preset-name")?.focus();
  }

  async function close() {
    naming = false;
    error = "";
    save.reset();
    await tick();
    document.getElementById("save-as-preset")?.focus();
  }

  /** Drop the message once anything in the form changes. */
  export function clearError() {
    error = "";
    if (save.isError) {
      save.reset();
    }
  }

  function submit() {
    if (save.isPending) {
      return;
    }
    const nameProblem = presetNameProblem(name);
    if (nameProblem) {
      error = nameProblem;
      return;
    }
    const body = build();
    if (typeof body === "string") {
      error = body;
      return;
    }
    save.mutate({ name: name.trim(), body });
  }

  /** Enter saves the preset, not the session around it. */
  function onkeydown(event: KeyboardEvent) {
    if (event.key === "Enter") {
      event.preventDefault();
      submit();
    }
  }
</script>

{#if naming}
  <div
    class="grid gap-3 rounded-3xl border border-edge bg-field p-5"
    role="group"
    aria-label="Save as preset"
    oninput={clearError}
  >
    <TextField
      id="preset-name"
      label="Preset name"
      autocomplete="off"
      bind:value={name}
      {onkeydown}
    />
    <p class="text-muted">Saves what the form shows now. The session itself isn't saved.</p>
    {#if error || saveError}
      <p class="font-medium" role="alert">{error || saveError}</p>
    {/if}
    <div class="flex flex-wrap gap-2">
      <Button variant="outline" disabled={save.isPending} onclick={submit}>Save preset</Button>
      <Button variant="quiet" disabled={save.isPending} onclick={close}>Cancel</Button>
    </div>
  </div>
{:else}
  <div class="-ml-3 flex flex-wrap items-center gap-x-1">
    <Button id="save-as-preset" variant="quiet" onclick={open}>Save as preset</Button>
    {#if savedAs}
      <p class="px-3 text-muted" role="status">Saved as {savedAs}.</p>
    {/if}
  </div>
{/if}
