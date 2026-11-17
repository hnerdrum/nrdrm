<script lang="ts">
  import Button from "./Button.svelte";

  type Props = {
    /** The block's key, for the button ids focus moves to. */
    key: string;
    /** What the block is called in the remove button, such as "interval". */
    noun: string;
    index: number;
    total: number;
    onmove: (direction: -1 | 1) => void;
    onremove: () => void;
  };

  let { key, noun, index, total, onmove, onremove }: Props = $props();
</script>

<div class="-ml-2 flex flex-wrap gap-x-1">
  <Button id="move-up-{key}" variant="quiet" disabled={index === 0} onclick={() => onmove(-1)}>
    Move up
  </Button>
  <Button
    id="move-down-{key}"
    variant="quiet"
    disabled={index === total - 1}
    onclick={() => onmove(1)}
  >
    Move down
  </Button>
  <Button variant="quiet" onclick={onremove}>Remove {noun}</Button>
</div>
