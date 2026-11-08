<script lang="ts">
  import { plural } from "../format";
  import type { LoggedSession } from "../api/sessions";
  import AddSessionButton from "./AddSessionButton.svelte";
  import Dock from "./Dock.svelte";
  import SessionList from "./SessionList.svelte";
  import SyncGarmin from "./SyncGarmin.svelte";
  import WeekFigures from "./WeekFigures.svelte";
  import WeekHeader from "./WeekHeader.svelte";

  type Props = {
    monday: string;
    today: string;
    sessions: LoggedSession[];
    status: "loading" | "ready" | "error";
    atCurrent: boolean;
    loggingOut: boolean;
    logoutError: string;
    syncing: boolean;
    syncMessage: string;
    syncFailed: boolean;
    onsync: () => void;
    onprevious: () => void;
    onnext: () => void;
    onadd: () => void;
    onopen: (session: LoggedSession) => void;
    onsessions: () => void;
    onlogout: () => void;
  };

  let {
    monday,
    today,
    sessions,
    status,
    atCurrent,
    loggingOut,
    logoutError,
    syncing,
    syncMessage,
    syncFailed,
    onsync,
    onprevious,
    onnext,
    onadd,
    onopen,
    onsessions,
    onlogout,
  }: Props = $props();
</script>

<div class="pb-[calc(6.75rem+env(safe-area-inset-bottom,0px))] wide:pb-12">
  <WeekHeader {monday} {atCurrent} {loggingOut} {onprevious} {onnext} {onadd} {onlogout} />
  {#if logoutError}
    <p class="mx-auto mt-6 max-w-272 font-medium" role="alert">{logoutError}</p>
  {/if}
  <main class="week-enter mx-auto max-w-272" aria-busy={status === "loading"}>
    {#if status === "error"}
      <p class="py-6 font-medium" role="alert">Couldn't load this week.</p>
      <SyncGarmin {syncing} message={syncMessage} failed={syncFailed} {onsync} />
    {:else if status === "ready"}
      <WeekFigures {sessions} />
      <SyncGarmin {syncing} message={syncMessage} failed={syncFailed} {onsync} />
      <button
        type="button"
        class="count mt-6 flex min-h-15 w-full items-center justify-between border-y border-line bg-transparent px-1 text-lg font-medium hover:text-accent wide:hidden"
        onclick={onsessions}
      >
        <span>{plural(sessions.length, "session", "sessions")}</span>
        <span class="text-2xl font-light text-muted" aria-hidden="true">›</span>
      </button>
      <section class="hidden wide:block">
        <h2 class="pt-12 pb-4 text-base font-medium tracking-[0.16em] text-muted uppercase">
          Sessions
        </h2>
        {#if sessions.length === 0}
          <div class="empty grid justify-items-start gap-6 py-6">
            <p class="text-[1.75rem] leading-[1.15] font-light tracking-[-0.03em]">
              Nothing logged this week.
            </p>
            <AddSessionButton onclick={onadd} />
          </div>
        {:else}
          <SessionList {sessions} {today} {onopen} />
        {/if}
      </section>
    {/if}
  </main>
  <Dock onclick={onadd} />
</div>
