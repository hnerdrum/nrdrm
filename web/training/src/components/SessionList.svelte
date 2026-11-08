<script lang="ts">
  import type { LoggedSession } from "../api/sessions";
  import { groupByDate } from "../days";
  import SessionRow from "./SessionRow.svelte";

  type Props = {
    sessions: LoggedSession[];
    today: string;
    onopen: (session: LoggedSession) => void;
  };

  let { sessions, today, onopen }: Props = $props();
  const days = $derived(groupByDate(sessions));
</script>

<div>
  {#each days as day (day.date)}
    <div class="day border-t border-line">
      {#each day.sessions as session (session.id)}
        <SessionRow {session} {today} {onopen} />
      {/each}
    </div>
  {/each}
</div>
