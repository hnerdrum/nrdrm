<script lang="ts">
  import { onMount } from "svelte";
  import { addDays, mondayOf, todayIso, weekOffset } from "../dates";
  import { listSessions, type LoggedSession } from "../log";
  import NewSession from "./NewSession.svelte";
  import SessionsScreen from "./SessionsScreen.svelte";
  import WeekScreen from "./WeekScreen.svelte";

  type Props = {
    loggingOut: boolean;
    logoutError: string;
    onlogout: () => void;
    onsignedout: () => void;
  };

  type View = "week" | "sessions" | "new";

  let { loggingOut, logoutError, onlogout, onsignedout }: Props = $props();

  const today = todayIso();
  let offset = $state(0);
  let view = $state<View>("week");
  let returnTo = $state<"week" | "sessions">("week");
  let sessions = $state<LoggedSession[]>([]);
  let status = $state<"loading" | "ready" | "error">("loading");
  let request = $state(0);
  let shownMonday = "";
  let wide = $state(
    typeof window !== "undefined" && window.matchMedia("(min-width: 960px)").matches,
  );

  const monday = $derived(addDays(mondayOf(today), offset * 7));
  const atCurrent = $derived(offset === 0);

  function previous() {
    offset -= 1;
  }

  function next() {
    if (offset < 0) {
      offset += 1;
    }
  }

  function openNew() {
    returnTo = view === "sessions" ? "sessions" : "week";
    view = "new";
  }

  function cancelNew() {
    view = returnTo;
    window.scrollTo(0, 0);
  }

  function saved(onDate: string) {
    offset = Math.min(0, weekOffset(mondayOf(today), mondayOf(onDate)));
    request += 1;
    view = returnTo;
    window.scrollTo(0, 0);
  }

  $effect(() => {
    if (wide && view === "sessions") {
      view = "week";
    }
  });

  $effect(() => {
    const from = monday;
    const to = addDays(from, 6);
    void request;
    let cancelled = false;
    if (shownMonday !== from) {
      status = "loading";
      sessions = [];
    }

    listSessions(from, to)
      .then((result) => {
        if (cancelled) {
          return;
        }
        if (result === "unauthorized") {
          onsignedout();
          return;
        }
        sessions = result;
        shownMonday = from;
        status = "ready";
      })
      .catch(() => {
        if (cancelled) {
          return;
        }
        sessions = [];
        shownMonday = "";
        status = "error";
      });

    return () => {
      cancelled = true;
    };
  });

  onMount(() => {
    const query = window.matchMedia("(min-width: 960px)");
    const onChange = () => {
      wide = query.matches;
    };
    query.addEventListener("change", onChange);
    return () => query.removeEventListener("change", onChange);
  });
</script>

{#if view === "new"}
  <NewSession {today} oncancel={cancelNew} onsaved={saved} {onsignedout} />
{:else if view === "sessions"}
  <SessionsScreen
    {monday}
    {today}
    {sessions}
    {status}
    onback={() => (view = "week")}
    onadd={openNew}
  />
{:else}
  <WeekScreen
    {monday}
    {today}
    {sessions}
    {status}
    {atCurrent}
    {loggingOut}
    {logoutError}
    onprevious={previous}
    onnext={next}
    onadd={openNew}
    onsessions={() => (view = "sessions")}
    {onlogout}
  />
{/if}
