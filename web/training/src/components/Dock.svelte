<script lang="ts">
  import AddSessionButton from "./AddSessionButton.svelte";

  type Props = {
    onclick: () => void;
  };

  let { onclick }: Props = $props();
</script>

<div
  class="fixed inset-x-0 bottom-0 z-10 border-t border-line bg-[rgba(19,18,28,0.82)] pt-3.5 pr-[max(16px,env(safe-area-inset-right,0px))] pb-[calc(0.875rem+env(safe-area-inset-bottom,0px))] pl-[max(16px,env(safe-area-inset-left,0px))] backdrop-blur-lg wide:hidden"
>
  <AddSessionButton class="mx-auto w-full max-w-lg" {onclick} />
</div>
