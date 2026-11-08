<script lang="ts">
  import Button from "./Button.svelte";

  type Props = {
    class?: string;
    onclick: () => void;
  };

  let { class: className = "", onclick }: Props = $props();
</script>

<Button variant="accent" class={className} {onclick}>
  <span class="-mt-[0.1em] font-mono text-2xl leading-none font-normal" aria-hidden="true">+</span>
  Add session
</Button>
