<script lang="ts">
  type Props = {
    value: string;
    index?: number;
  };

  let { value, index = 0 }: Props = $props();

  const places = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
</script>

{#each value.split("") as glyph, offset (offset)}
  <span class="inline-block h-[1em] overflow-hidden leading-none">
    <span class="odo flex flex-col" style="--v: {glyph}; --i: {index + offset}">
      {#each places as place (place)}
        <span class="block h-[1em] leading-none">{place}</span>
      {/each}
    </span>
  </span>
{/each}
