<script lang="ts">
  import { untrack } from "svelte";
  import type { SessionBody } from "../domain";
  import { formatDay } from "../dates";
  import {
    buildBody,
    draftFrom,
    emptyBlock,
    emptyDistanceDraft,
    type DistanceDraft,
    type DraftBlock,
  } from "../draft";
  import BlockListEditor from "./BlockListEditor.svelte";
  import DistanceEditor from "./DistanceEditor.svelte";

  type Props = {
    /** The sport whose fields are shown. Bind it to a `SportPicker`;
     * `fill` changes it too. */
    sport?: SessionBody["sport"];
    /** The body to show first. Read once, when the editor mounts; set `sport`
     * to its sport as well. */
    initial?: SessionBody | null;
    /** Hide the exercises behind a loading note while they are fetched. */
    loadingExercises?: boolean;
    /** A note above the exercises, such as why they couldn't be filled. */
    exercisesNote?: string;
    /** The date of the session the exercises were filled from. */
    prefilledFrom?: string | null;
  };

  let {
    sport = $bindable("run"),
    initial = null,
    loadingExercises = false,
    exercisesNote = "",
    prefilledFrom = null,
  }: Props = $props();

  const first = untrack(() => (initial ? draftFrom(initial) : null));

  let distance = $state<DistanceDraft>(
    first && first.sport !== "strength" ? first.distance : emptyDistanceDraft(),
  );
  let strength = $state<DraftBlock[]>(
    first?.sport === "strength" ? first.blocks : [emptyBlock("exercise")],
  );

  /** Show `body` in the fields of its sport, without changing the sport shown.
   * A strength body with no exercise leaves an empty one to fill in. */
  export function seed(body: SessionBody) {
    const draft = draftFrom(body);
    if (draft.sport === "strength") {
      strength = draft.blocks.some((block) => block.kind === "exercise")
        ? draft.blocks
        : [...draft.blocks, emptyBlock("exercise")];
    } else {
      distance = draft.distance;
    }
  }

  /** Show `body` and switch to its sport. */
  export function fill(body: SessionBody) {
    seed(body);
    sport = body.sport;
  }

  /** The body the fields show, or what to fix before it can be saved. */
  export function build(): SessionBody | string {
    return buildBody(sport, distance, strength);
  }
</script>

{#if sport === "strength"}
  {#if loadingExercises}
    <p class="text-muted" role="status">Loading exercises…</p>
  {:else}
    {#if exercisesNote}
      <p class="text-muted" role="status">{exercisesNote}</p>
    {/if}
    <div class="rise-in grid gap-7">
      {#if prefilledFrom}
        <p class="text-muted">
          From your last strength session, {formatDay(prefilledFrom)}. Change what you need.
        </p>
      {/if}
      <BlockListEditor {sport} blocks={strength} onchange={(next) => (strength = next)} />
    </div>
  {/if}
{:else}
  <DistanceEditor
    {sport}
    bind:kilometres={distance.kilometres}
    bind:hours={distance.hours}
    bind:minutes={distance.minutes}
    blocks={distance.blocks}
    onchange={(next) => (distance.blocks = next)}
  />
{/if}
