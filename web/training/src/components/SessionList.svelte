<script lang="ts">
  import { groupByDate, type LoggedSession } from "../log";
  import SessionRow from "./SessionRow.svelte";

  type Props = {
    sessions: LoggedSession[];
    today: string;
  };

  let { sessions, today }: Props = $props();
  const days = $derived(groupByDate(sessions));
</script>

<div>
  {#each days as day (day.date)}
    <div class="day border-t border-line">
      {#each day.sessions as session (session.id)}
        <SessionRow {session} {today} />
      {/each}
    </div>
  {/each}
</div>
