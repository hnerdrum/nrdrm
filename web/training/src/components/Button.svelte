<script lang="ts">
  import type { Snippet } from "svelte";

  type Props = {
    variant?: "solid" | "quiet" | "accent" | "icon";
    type?: "button" | "submit";
    disabled?: boolean;
    label?: string;
    class?: string;
    onclick?: (event: MouseEvent) => void;
    children: Snippet;
  };

  let {
    variant = "solid",
    type = "button",
    disabled = false,
    label,
    class: className = "",
    onclick,
    children,
  }: Props = $props();

  const classes = {
    solid:
      "flex min-h-[52px] w-full bg-fg px-7 font-semibold tracking-[0.01em] text-bg hover:-translate-y-px hover:brightness-110 active:translate-y-0 active:scale-[0.985]",
    quiet:
      "inline-flex min-h-11 px-3 text-muted hover:text-fg hover:underline hover:underline-offset-[0.3em] hover:decoration-1",
    accent:
      "inline-flex min-h-[52px] gap-2 bg-accent px-7 font-semibold tracking-[0.01em] text-on-accent shadow-[inset_0_1px_0_rgba(255,255,255,0.5),0_14px_30px_-14px_rgba(180,185,255,0.55)] hover:-translate-y-px hover:no-underline hover:brightness-105 hover:shadow-[inset_0_1px_0_rgba(255,255,255,0.5),0_18px_34px_-14px_rgba(180,185,255,0.55)] active:translate-y-0 active:scale-[0.985]",
    icon: "inline-flex size-11 p-0 text-[1.375rem] font-light hover:bg-field hover:no-underline disabled:hover:bg-transparent",
  };
</script>

<button
  {type}
  {disabled}
  aria-label={label}
  {onclick}
  class="cursor-pointer items-center justify-center rounded-full border-0 transition duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] disabled:cursor-default disabled:opacity-30 disabled:hover:no-underline {classes[
    variant
  ]} {className}"
>
  {@render children()}
</button>
