<script lang="ts">
  import { formatDay } from "../dates";
  import { sessionDuration, sessionMain, sportLabel } from "../format";
  import type { LoggedSession } from "../api/sessions";

  type Props = {
    session: LoggedSession;
    today: string;
    onopen: (session: LoggedSession) => void;
  };

  let { session, today, onopen }: Props = $props();

  const main = $derived(sessionMain(session.body));
  const duration = $derived(sessionDuration(session.body));
</script>

<button
  type="button"
  class="grid w-[calc(100%+1.5rem)] -mx-3 min-h-20 cursor-pointer grid-cols-[1fr_auto] items-baseline gap-x-4 gap-y-0.5 border-0 bg-transparent px-3 py-4 text-left hover:bg-field wide:-mx-5 wide:min-h-17 wide:w-[calc(100%+2.5rem)] wide:grid-cols-[9.5rem_11rem_9rem_1fr] wide:px-5 wide:py-4"
  onclick={() => onopen(session)}
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
</button>
