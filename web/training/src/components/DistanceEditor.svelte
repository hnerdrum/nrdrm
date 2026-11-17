<script lang="ts">
  import { draftTotals, type DistanceSport, type DraftBlock } from "../draft";
  import { formatDuration, formatKm, sportLabel } from "../format";
  import BlockListEditor from "./BlockListEditor.svelte";
  import DistanceFields from "./DistanceFields.svelte";

  type Props = {
    sport: DistanceSport;
    kilometres?: string;
    hours?: string;
    minutes?: string;
    blocks: DraftBlock[];
    onchange: (blocks: DraftBlock[]) => void;
  };

  let {
    sport,
    kilometres = $bindable(""),
    hours = $bindable(""),
    minutes = $bindable(""),
    blocks,
    onchange,
  }: Props = $props();

  const sums = $derived(blocks.length > 0 ? draftTotals(blocks) : null);

  /** What a blank total stands for: the blocks' sum, rounded to the field. */
  const blank = $derived.by(() => {
    if (!sums) {
      return null;
    }
    const totalMinutes = Math.round(sums.duration / 60);
    return {
      kilometres: sums.distance > 0 ? String(sums.distance / 1000) : "",
      hours: sums.duration > 0 ? String(Math.floor(totalMinutes / 60)) : "",
      minutes: sums.duration > 0 ? String(totalMinutes % 60) : "",
    };
  });

  const summary = $derived.by(() => {
    if (!sums) {
      return null;
    }
    const parts: string[] = [];
    if (sums.distance > 0) {
      parts.push(formatKm(sums.distance));
    }
    if (sums.duration > 0) {
      const seconds = sums.duration % 60;
      parts.push(
        seconds === 0
          ? formatDuration(sums.duration)
          : `${formatDuration(sums.duration)} ${String(seconds).padStart(2, "0")}s`,
      );
    }
    return parts.length > 0 ? parts.join(" · ") : null;
  });
</script>

<div class="grid gap-7">
  <div class="grid gap-2">
    <h2 class="text-muted">{sportLabel(sport)}</h2>
    {#if blocks.length > 0}
      <p class="text-muted">
        The whole session. Leave a field blank to use what the blocks add up to.
      </p>
    {/if}
  </div>
  <DistanceFields {sport} bind:kilometres bind:hours bind:minutes {blank} />
  <section class="grid gap-5" aria-label="Blocks">
    <div class="grid gap-1">
      <h2 class="text-lg font-medium">Blocks</h2>
      <p class="text-muted">
        Optional. Outline the session in order: warmup, intervals, cooldown.
      </p>
    </div>
    <BlockListEditor {sport} {blocks} {onchange} />
    {#if summary}
      <p class="font-mono text-muted tabular-nums">Blocks: {summary}</p>
    {/if}
  </section>
</div>
