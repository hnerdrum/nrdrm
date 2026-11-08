<script lang="ts">
  import { formatRange } from "../dates";
  import type { LoggedSession } from "../log";
  import AddSessionButton from "./AddSessionButton.svelte";
  import Button from "./Button.svelte";
  import Dock from "./Dock.svelte";
  import SessionList from "./SessionList.svelte";

  type Props = {
    monday: string;
    today: string;
    sessions: LoggedSession[];
    status: "loading" | "ready" | "error";
    onback: () => void;
    onadd: () => void;
  };

  let { monday, today, sessions, status, onback, onadd }: Props = $props();
  const range = $derived(formatRange(monday));
</script>

<div class="pb-[calc(6.75rem+env(safe-area-inset-bottom,0px))] wide:pb-12">
  <div class="week-enter mx-auto max-w-272">
    <header class="-ml-3 pt-3">
      <Button variant="quiet" onclick={onback}>← Week</Button>
    </header>
    <h1 class="mt-4 text-[clamp(2.5rem,12vw,3rem)] leading-none font-light tracking-tighter">
      Sessions
    </h1>
    <p class="mt-3 mb-6 text-muted tabular-nums">{range}</p>
    {#if status === "error"}
      <p class="font-medium" role="alert">Couldn't load this week.</p>
    {:else if status === "ready" && sessions.length === 0}
      <div class="empty grid justify-items-start gap-6 py-6">
        <p class="text-[1.75rem] leading-[1.15] font-light tracking-[-0.03em]">
          Nothing logged this week.
        </p>
        <AddSessionButton onclick={onadd} />
      </div>
    {:else if status === "ready"}
      <SessionList {sessions} {today} />
    {/if}
  </div>
  {#if status === "ready" && sessions.length > 0}
    <Dock onclick={onadd} />
  {/if}
</div>
