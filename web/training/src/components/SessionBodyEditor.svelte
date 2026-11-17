<script lang="ts">
  import { untrack } from "svelte";
  import type { SessionBody } from "../domain";
  import {
    buildBody,
    draftFrom,
    emptyDistanceDraft,
    emptyExercise,
    type DistanceDraft,
    type DraftExercise,
  } from "../draft";
  import DistanceEditor from "./DistanceEditor.svelte";
  import StrengthEditor from "./StrengthEditor.svelte";

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
  let exercises = $state<DraftExercise[]>(
    first?.sport === "strength" ? first.exercises : [emptyExercise()],
  );

  /** Show `body` in the fields of its sport, without changing the sport shown.
   * A strength body with no exercises leaves one empty exercise to fill in. */
  export function seed(body: SessionBody) {
    const draft = draftFrom(body);
    if (draft.sport === "strength") {
      exercises = draft.exercises.length > 0 ? draft.exercises : [emptyExercise()];
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
    return buildBody(sport, distance, exercises);
  }
</script>

{#if sport === "strength"}
  {#if loadingExercises}
    <p class="text-muted" role="status">Loading exercises…</p>
  {:else}
    {#if exercisesNote}
      <p class="text-muted" role="status">{exercisesNote}</p>
    {/if}
    <StrengthEditor {exercises} {prefilledFrom} onchange={(next) => (exercises = next)} />
  {/if}
{:else}
  <DistanceEditor
    {sport}
    bind:kind={distance.kind}
    bind:kilometres={distance.kilometres}
    bind:hours={distance.hours}
    bind:minutes={distance.minutes}
    intervals={distance.intervals}
    onchange={(next) => (distance.intervals = next)}
  />
{/if}
