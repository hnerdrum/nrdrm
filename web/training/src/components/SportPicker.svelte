<script lang="ts">
  import type { SessionBody } from "../domain";
  import { sportLabel } from "../format";

  type Sport = SessionBody["sport"];

  type Props = {
    sport?: Sport;
    locked?: boolean;
  };

  const sports: Sport[] = ["run", "ride", "ski", "strength"];

  let { sport = $bindable("run"), locked = false }: Props = $props();

  const position = $derived(sports.indexOf(sport));
</script>

<fieldset class="m-0 grid min-w-0 gap-2 border-0 p-0">
  <legend class="p-0 text-muted">Sport</legend>
  <div
    class="relative grid grid-cols-4 rounded-full border border-edge bg-field p-1"
    style:--pos={position}
  >
    <span class="thumb" aria-hidden="true"></span>
    {#each sports as item (item)}
      <label class="relative z-1 {locked && item !== sport ? 'cursor-default' : ''}">
        <input
          class="peer absolute inset-0 m-0 cursor-pointer opacity-0 focus-visible:outline-none disabled:cursor-default"
          type="radio"
          name="sport"
          value={item}
          checked={sport === item}
          disabled={locked && item !== sport}
          onchange={() => (sport = item)}
        />
        <span
          class="flex min-h-12 items-center justify-center rounded-full px-1 font-medium text-muted transition-colors duration-300 peer-hover:text-fg peer-disabled:text-muted peer-disabled:hover:text-muted peer-checked:font-semibold peer-checked:text-on-accent peer-focus-visible:outline peer-focus-visible:outline-offset-[3px] peer-focus-visible:outline-accent"
        >
          {sportLabel(item)}
        </span>
      </label>
    {/each}
  </div>
</fieldset>

<style>
  .thumb {
    position: absolute;
    top: 4px;
    bottom: 4px;
    left: 4px;
    width: calc((100% - 8px) / 4);
    border-radius: 999px;
    background: var(--color-accent);
    box-shadow:
      inset 0 1px 0 rgba(255, 255, 255, 0.5),
      0 10px 22px -10px rgba(180, 185, 255, 0.55);
    transform: translateX(calc(var(--pos) * 100%));
    transition: transform 0.5s cubic-bezier(0.16, 1, 0.3, 1);
    pointer-events: none;
  }

  @media (prefers-reduced-motion: reduce) {
    .thumb {
      transition: none;
    }
  }
</style>
