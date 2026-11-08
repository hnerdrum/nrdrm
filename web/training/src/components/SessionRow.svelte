<script lang="ts">
  import { formatDay } from "../dates";
  import { sessionDuration, sessionMain, sportLabel } from "../format";
  import type { LoggedSession } from "../log";

  type Props = {
    session: LoggedSession;
    today: string;
  };

  let { session, today }: Props = $props();

  const main = $derived(sessionMain(session.body));
  const duration = $derived(sessionDuration(session.body));
</script>

<div
  class="grid w-[calc(100%+1.5rem)] -mx-3 min-h-20 grid-cols-[1fr_auto] items-baseline gap-x-4 gap-y-0.5 px-3 py-4 text-left wide:-mx-5 wide:min-h-17 wide:w-[calc(100%+2.5rem)] wide:grid-cols-[9.5rem_11rem_9rem_1fr] wide:px-5 wide:py-4"
>
  <span class="col-start-1 row-start-1 text-muted tabular-nums">
    {formatDay(session.onDate)}
    {#if session.onDate === today}
      <em class="ml-2.5 text-fg not-italic">Today</em>
    {/if}
  </span>
  <span
    class="col-start-1 row-start-2 flex items-center gap-3 text-xl font-medium tracking-tight wide:col-start-2 wide:row-start-1"
  >
    {sportLabel(session.body.sport)}
    {#if session.body.sport === "ski" && session.body.withPack}
      <span class="rounded-full border border-edge px-[0.65rem] text-base leading-[1.4] font-medium"
        >Pack</span
      >
    {/if}
  </span>
  <span
    class="col-start-2 row-start-2 text-right text-xl leading-[1.3] tabular-nums wide:col-start-3 wide:row-start-1 wide:text-left {main.plain
      ? 'font-sans tracking-[-0.01em]'
      : 'font-mono tracking-[-0.03em]'}"
  >
    {main.text}
  </span>
  {#if duration}
    <span
      class="col-start-2 row-start-1 text-right font-mono text-muted tabular-nums wide:col-start-4 wide:row-start-1 wide:text-left"
    >
      {duration}
    </span>
  {/if}
</div>
