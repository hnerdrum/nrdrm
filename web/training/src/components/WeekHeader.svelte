<script lang="ts">
  import { isoWeek, rangeParts } from "../dates";
  import AddSessionButton from "./AddSessionButton.svelte";
  import Button from "./Button.svelte";

  type Props = {
    monday: string;
    atCurrent: boolean;
    loggingOut: boolean;
    onprevious: () => void;
    onnext: () => void;
    onadd: () => void;
    onlogout: () => void;
  };

  let { monday, atCurrent, loggingOut, onprevious, onnext, onadd, onlogout }: Props = $props();

  const range = $derived(rangeParts(monday));
  const weekNumber = $derived(isoWeek(monday));
</script>

<header
  class="week-header mx-auto grid max-w-272 grid-cols-[1fr_auto] items-center gap-x-4 pt-3 wide:min-h-30 wide:grid-cols-[auto_1fr_auto_auto] wide:gap-x-12 wide:p-0"
>
  <p class="text-base font-semibold tracking-[0.18em] uppercase [grid-area:brand]">Training</p>
  <nav
    class="-mx-2 flex items-center gap-1 pt-5 pb-6 wide:mx-0 wide:justify-start wide:gap-2 wide:p-0 [grid-area:nav]"
    aria-label="Week"
  >
    <Button variant="icon" label="Previous week" onclick={onprevious}>←</Button>
    <h1
      class="flex-1 text-center leading-none wide:flex wide:min-w-68 wide:flex-none wide:items-baseline wide:gap-4 wide:text-left"
    >
      <span
        class="block text-[clamp(2.25rem,11vw,3rem)] font-light tracking-[-0.045em] tabular-nums wide:text-[2.75rem]"
        >{range.main}</span
      >
      <span class="mt-2 block text-base tracking-[0.02em] text-muted wide:mt-0"
        >{range.year} · Week {weekNumber}</span
      >
    </h1>
    <Button variant="icon" label="Next week" disabled={atCurrent} onclick={onnext}>→</Button>
  </nav>
  <div class="hidden [grid-area:add] wide:block">
    <AddSessionButton onclick={onadd} />
  </div>
  <div class="-mr-3 [grid-area:out]">
    <Button variant="quiet" type="button" disabled={loggingOut} onclick={onlogout}>Log out</Button>
  </div>
</header>
