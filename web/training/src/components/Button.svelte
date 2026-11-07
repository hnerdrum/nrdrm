<script lang="ts">
  import type { Snippet } from "svelte";

  type Props = {
    variant?: "solid" | "quiet";
    type?: "button" | "submit";
    disabled?: boolean;
    onclick?: (event: MouseEvent) => void;
    children: Snippet;
  };

  let {
    variant = "solid",
    type = "button",
    disabled = false,
    onclick,
    children,
  }: Props = $props();

  const classes = {
    solid:
      "flex min-h-[52px] w-full bg-fg px-7 font-semibold tracking-[0.01em] text-bg hover:-translate-y-px hover:brightness-110 active:translate-y-0 active:scale-[0.985]",
    quiet:
      "inline-flex min-h-11 px-3 text-muted hover:text-fg hover:underline hover:underline-offset-[0.3em] hover:decoration-1",
  };
</script>

<button
  {type}
  {disabled}
  {onclick}
  class="cursor-pointer items-center justify-center rounded-full border-0 transition duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] disabled:cursor-default disabled:opacity-30 {classes[variant]}"
>
  {@render children()}
</button>
