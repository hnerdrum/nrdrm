<script lang="ts">
  import { tick } from "svelte";
  import { formatDay } from "../dates";
  import { emptyExercise, emptySet, type DraftExercise, type SetMeasure } from "../draft";
  import Button from "./Button.svelte";
  import ExerciseCard from "./ExerciseCard.svelte";

  type Props = {
    exercises: DraftExercise[];
    prefilledFrom: string | null;
    onchange: (exercises: DraftExercise[]) => void;
  };

  let { exercises, prefilledFrom, onchange }: Props = $props();

  async function focus(id: string) {
    await tick();
    document.getElementById(id)?.focus();
  }

  async function focusEnabled(preferred: string, fallback: string) {
    await tick();
    const element = document.getElementById(preferred);
    if (element instanceof HTMLButtonElement && !element.disabled) {
      element.focus();
      return;
    }
    document.getElementById(fallback)?.focus();
  }

  function rename(key: string, name: string) {
    onchange(
      exercises.map((exercise) => (exercise.key === key ? { ...exercise, name } : exercise)),
    );
  }

  function editSet(
    exerciseKey: string,
    setKey: string,
    field: "reps" | "weight" | "minutes" | "seconds",
    value: string,
  ) {
    onchange(
      exercises.map((exercise) => {
        if (exercise.key !== exerciseKey) {
          return exercise;
        }
        return {
          ...exercise,
          sets: exercise.sets.map((set) => (set.key === setKey ? { ...set, [field]: value } : set)),
        };
      }),
    );
  }

  function addSet(exerciseKey: string) {
    const created = emptySet();
    const measure = exercises.find((exercise) => exercise.key === exerciseKey)?.measure ?? "reps";
    onchange(
      exercises.map((exercise) =>
        exercise.key === exerciseKey ? { ...exercise, sets: [...exercise.sets, created] } : exercise,
      ),
    );
    void focus(
      measure === "time" ? `set-${created.key}-seconds` : `set-${created.key}-reps`,
    );
  }

  function removeSet(exerciseKey: string, setKey: string) {
    onchange(
      exercises.map((exercise) => {
        if (exercise.key !== exerciseKey) {
          return exercise;
        }
        return { ...exercise, sets: exercise.sets.filter((set) => set.key !== setKey) };
      }),
    );
    void focus(`add-set-${exerciseKey}`);
  }

  function move(key: string, direction: -1 | 1) {
    const index = exercises.findIndex((exercise) => exercise.key === key);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= exercises.length) {
      return;
    }
    const next = exercises.slice();
    const [item] = next.splice(index, 1);
    next.splice(target, 0, item);
    onchange(next);
    const action = direction === -1 ? "up" : "down";
    const other = direction === -1 ? "down" : "up";
    void focusEnabled(`move-${action}-${key}`, `move-${other}-${key}`);
  }

  function setMeasure(key: string, measure: SetMeasure) {
    const exercise = exercises.find((item) => item.key === key);
    onchange(exercises.map((item) => (item.key === key ? { ...item, measure } : item)));
    const first = exercise?.sets[0];
    if (!first) {
      return;
    }
    void focus(measure === "time" ? `set-${first.key}-seconds` : `set-${first.key}-reps`);
  }

  function addExercise() {
    const created = emptyExercise();
    onchange([...exercises, created]);
    void focus(`exercise-${created.key}-name`);
  }

  function removeExercise(key: string) {
    onchange(exercises.filter((exercise) => exercise.key !== key));
    void focus("add-exercise");
  }
</script>

<div class="rise-in grid gap-7">
  {#if prefilledFrom}
    <p class="text-muted">
      From your last strength session, {formatDay(prefilledFrom)}. Change what you need.
    </p>
  {/if}
  {#each exercises as exercise, index (exercise.key)}
    <ExerciseCard
      {exercise}
      {index}
      total={exercises.length}
      onname={(name) => rename(exercise.key, name)}
      onmeasure={(measure) => setMeasure(exercise.key, measure)}
      onset={(setKey, field, value) => editSet(exercise.key, setKey, field, value)}
      onaddset={() => addSet(exercise.key)}
      onremoveset={(setKey) => removeSet(exercise.key, setKey)}
      onmove={(direction) => move(exercise.key, direction)}
      onremove={() => removeExercise(exercise.key)}
    />
  {/each}
  <div>
    <Button id="add-exercise" variant="outline" onclick={addExercise}>Add exercise</Button>
  </div>
</div>
