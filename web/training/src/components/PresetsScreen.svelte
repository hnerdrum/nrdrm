<script lang="ts">
  import { createQuery } from "@tanstack/svelte-query";
  import { listPresets, presetsQueryKey, type Preset } from "../api/presets";
  import type { SessionBody } from "../domain";
  import { presetSummary, sportLabel } from "../format";
  import Button from "./Button.svelte";

  type Props = {
    onback: () => void;
    onadd: () => void;
    onopen: (preset: Preset) => void;
  };

  let { onback, onadd, onopen }: Props = $props();

  const sports: SessionBody["sport"][] = ["run", "ride", "ski", "strength"];

  const presets = createQuery(() => ({
    queryKey: presetsQueryKey,
    queryFn: listPresets,
  }));

  /** The presets of each sport that has any, in the server's order. */
  const groups = $derived(
    sports
      .map((sport) => ({
        sport,
        presets: (presets.data ?? []).filter((preset) => preset.body.sport === sport),
      }))
      .filter((group) => group.presets.length > 0),
  );
</script>

<div class="pb-[calc(6.75rem+env(safe-area-inset-bottom,0px))] wide:pb-12">
  <div class="week-enter mx-auto max-w-272">
    <header class="-ml-3 pt-3">
      <Button variant="quiet" onclick={onback}>← Week</Button>
    </header>
    <div class="mt-4 flex flex-wrap items-end justify-between gap-4">
      <h1 class="text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
        Presets
      </h1>
      {#if presets.data && presets.data.length > 0}
        <div class="hidden wide:block">
          <Button variant="accent" onclick={onadd}>New preset</Button>
        </div>
      {/if}
    </div>
    <p class="mt-3 mb-6 max-w-104 text-muted">
      Sessions you do the same way every time. Pick one on a new session to fill it in.
    </p>
    <div aria-busy={presets.isPending}>
      {#if presets.isError && presets.data === undefined}
        <p class="font-medium" role="alert">Couldn't load your presets.</p>
        <div class="mt-4">
          <Button
            variant="outline"
            disabled={presets.isFetching}
            onclick={() => presets.refetch()}
          >
            Try again
          </Button>
        </div>
      {:else if presets.data && presets.data.length === 0}
        <div class="empty grid justify-items-start gap-6 py-6">
          <p class="text-[1.75rem] leading-[1.15] font-light tracking-[-0.03em]">
            No presets yet.
          </p>
          <Button variant="accent" onclick={onadd}>New preset</Button>
        </div>
      {:else if presets.data}
        {#each groups as group (group.sport)}
          <section>
            <h2 class="pt-8 pb-2 text-base font-medium tracking-[0.16em] text-muted uppercase">
              {sportLabel(group.sport)}
            </h2>
            <ul class="m-0 list-none border-t border-line p-0">
              {#each group.presets as preset (preset.id)}
                <li class="border-b border-line">
                  <button
                    type="button"
                    class="-mx-3 grid min-h-17 w-[calc(100%+1.5rem)] cursor-pointer gap-0.5 border-0 bg-transparent px-3 py-3.5 text-left hover:bg-field wide:-mx-5 wide:w-[calc(100%+2.5rem)] wide:px-5"
                    onclick={() => onopen(preset)}
                  >
                    <span class="text-xl font-medium tracking-tight">{preset.name}</span>
                    <span class="truncate text-muted">{presetSummary(preset.body)}</span>
                  </button>
                </li>
              {/each}
            </ul>
          </section>
        {/each}
      {/if}
    </div>
  </div>
  {#if presets.data && presets.data.length > 0}
    <div
      class="fixed inset-x-0 bottom-0 z-10 border-t border-line bg-[rgba(19,18,28,0.82)] pt-3.5 pr-[max(16px,env(safe-area-inset-right,0px))] pb-[calc(0.875rem+env(safe-area-inset-bottom,0px))] pl-[max(16px,env(safe-area-inset-left,0px))] backdrop-blur-lg wide:hidden"
    >
      <Button variant="accent" class="mx-auto w-full max-w-lg" onclick={onadd}>New preset</Button>
    </div>
  {/if}
</div>
