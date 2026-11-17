<script lang="ts">
  import { tick } from "svelte";
  import type { SessionBody } from "../domain";
  import {
    blockKinds,
    emptyBlock,
    emptySet,
    type BlockKind,
    type DistanceSport,
    type DraftBlock,
    type SetMeasure,
  } from "../draft";
  import Button from "./Button.svelte";
  import ExerciseCard from "./ExerciseCard.svelte";
  import RepeatsBlock from "./RepeatsBlock.svelte";
  import SteadyBlock from "./SteadyBlock.svelte";

  type Props = {
    sport: SessionBody["sport"];
    blocks: DraftBlock[];
    onchange: (blocks: DraftBlock[]) => void;
  };

  let { sport, blocks, onchange }: Props = $props();

  const ADD_LABEL: Record<BlockKind, string> = {
    steady: "Add steady part",
    repeats: "Add intervals",
    exercise: "Add exercise",
  };

  const FIRST_FIELD: Record<BlockKind, (key: string) => string> = {
    steady: (key) => `steady-${key}-name`,
    repeats: (key) => `interval-${key}-repeats`,
    exercise: (key) => `exercise-${key}-name`,
  };

  /** Each block's number among the blocks of its kind, for labels. */
  const numbers = $derived.by(() => {
    const counts: Record<BlockKind, number> = { steady: 0, repeats: 0, exercise: 0 };
    return blocks.map((block) => ++counts[block.kind]);
  });

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

  /** `block` with `change` applied, keeping its kind. */
  function update(key: string, change: (block: DraftBlock) => DraftBlock) {
    onchange(blocks.map((block) => (block.key === key ? change(block) : block)));
  }

  function edit(key: string, field: string, value: string) {
    update(key, (block) => ({ ...block, [field]: value }) as DraftBlock);
  }

  function editSet(
    key: string,
    setKey: string,
    field: "reps" | "weight" | "minutes" | "seconds",
    value: string,
  ) {
    update(key, (block) =>
      block.kind === "exercise"
        ? {
            ...block,
            sets: block.sets.map((set) => (set.key === setKey ? { ...set, [field]: value } : set)),
          }
        : block,
    );
  }

  function addSet(key: string) {
    const created = emptySet();
    const block = blocks.find((item) => item.key === key);
    const measure = block?.kind === "exercise" ? block.measure : "reps";
    update(key, (item) =>
      item.kind === "exercise" ? { ...item, sets: [...item.sets, created] } : item,
    );
    void focus(measure === "time" ? `set-${created.key}-seconds` : `set-${created.key}-reps`);
  }

  function removeSet(key: string, setKey: string) {
    update(key, (block) =>
      block.kind === "exercise"
        ? { ...block, sets: block.sets.filter((set) => set.key !== setKey) }
        : block,
    );
    void focus(`add-set-${key}`);
  }

  function setMeasure(key: string, measure: SetMeasure) {
    const block = blocks.find((item) => item.key === key);
    update(key, (item) => (item.kind === "exercise" ? { ...item, measure } : item));
    const first = block?.kind === "exercise" ? block.sets[0] : undefined;
    if (first) {
      void focus(measure === "time" ? `set-${first.key}-seconds` : `set-${first.key}-reps`);
    }
  }

  function move(key: string, direction: -1 | 1) {
    const index = blocks.findIndex((block) => block.key === key);
    const target = index + direction;
    if (index < 0 || target < 0 || target >= blocks.length) {
      return;
    }
    const next = blocks.slice();
    const [item] = next.splice(index, 1);
    next.splice(target, 0, item);
    onchange(next);
    const action = direction === -1 ? "up" : "down";
    const other = direction === -1 ? "down" : "up";
    void focusEnabled(`move-${action}-${key}`, `move-${other}-${key}`);
  }

  function add(kind: BlockKind) {
    const created = emptyBlock(kind);
    onchange([...blocks, created]);
    void focus(FIRST_FIELD[kind](created.key));
  }

  function remove(key: string) {
    const kind = blocks.find((block) => block.key === key)?.kind ?? "steady";
    onchange(blocks.filter((block) => block.key !== key));
    void focus(`add-${kind}`);
  }
</script>

<div class="grid gap-7">
  {#each blocks as block, index (block.key)}
    <div class="rise-in">
      {#if block.kind === "steady"}
        <SteadyBlock
          steady={block}
          {index}
          total={blocks.length}
          onedit={(field, value) => edit(block.key, field, value)}
          onmove={(direction) => move(block.key, direction)}
          onremove={() => remove(block.key)}
        />
      {:else if block.kind === "repeats"}
        <RepeatsBlock
          sport={sport as DistanceSport}
          interval={block}
          {index}
          total={blocks.length}
          number={numbers[index]}
          onedit={(field, value) => edit(block.key, field, value)}
          onmove={(direction) => move(block.key, direction)}
          onremove={() => remove(block.key)}
        />
      {:else}
        <ExerciseCard
          exercise={block}
          {index}
          total={blocks.length}
          number={numbers[index]}
          onname={(name) => edit(block.key, "name", name)}
          onmeasure={(measure) => setMeasure(block.key, measure)}
          onset={(setKey, field, value) => editSet(block.key, setKey, field, value)}
          onaddset={() => addSet(block.key)}
          onremoveset={(setKey) => removeSet(block.key, setKey)}
          onmove={(direction) => move(block.key, direction)}
          onremove={() => remove(block.key)}
        />
      {/if}
    </div>
  {/each}
  <div class="flex flex-wrap gap-3">
    {#each blockKinds(sport) as kind (kind)}
      <Button id="add-{kind}" variant="outline" onclick={() => add(kind)}>{ADD_LABEL[kind]}</Button>
    {/each}
  </div>
</div>
