<script lang="ts">
  import { onMount } from "svelte";
  import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import { identityQueryKey, logout } from "../api/identity";
  import { listSessions, sessionsQueryKey } from "../api/sessions";
  import { addDays, mondayOf, todayIso, weekOffset } from "../dates";
  import NewSession from "./NewSession.svelte";
  import SessionsScreen from "./SessionsScreen.svelte";
  import WeekScreen from "./WeekScreen.svelte";

  type View = "week" | "sessions" | "new";

  const queryClient = useQueryClient();
  const today = todayIso();
  let offset = $state(0);
  let view = $state<View>("week");
  let returnTo = $state<"week" | "sessions">("week");
  let wide = $state(
    typeof window !== "undefined" && window.matchMedia("(min-width: 960px)").matches,
  );

  const monday = $derived(addDays(mondayOf(today), offset * 7));
  const atCurrent = $derived(offset === 0);

  const week = createQuery(() => ({
    queryKey: [...sessionsQueryKey, "week", monday],
    queryFn: () => listSessions(monday, addDays(monday, 6)),
  }));

  const sessions = $derived(week.data ?? []);
  const status = $derived.by(() => {
    if (week.isPending) {
      return "loading" as const;
    }
    if (week.isError && week.data === undefined) {
      return "error" as const;
    }
    return "ready" as const;
  });

  const logoutMutation = createMutation(() => ({
    mutationFn: logout,
    onSuccess: () => {
      queryClient.setQueryData(identityQueryKey, null);
      void queryClient.removeQueries({ queryKey: sessionsQueryKey });
    },
  }));

  const logoutError = $derived.by(() => {
    if (!logoutMutation.isError || isUnauthorized(logoutMutation.error)) {
      return "";
    }
    return "Couldn't log out. Try again.";
  });

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
    const nextOffset = Math.min(0, weekOffset(mondayOf(today), mondayOf(onDate)));
    const sameWeek = nextOffset === offset;
    offset = nextOffset;
    view = returnTo;
    window.scrollTo(0, 0);
    if (sameWeek) {
      void queryClient.invalidateQueries({
        queryKey: [...sessionsQueryKey, "week", monday],
      });
    }
  }

  function onLogout() {
    if (logoutMutation.isPending) {
      return;
    }
    logoutMutation.mutate();
  }

  $effect(() => {
    if (wide && view === "sessions") {
      view = "week";
    }
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
  <NewSession {today} oncancel={cancelNew} onsaved={saved} />
{:else if view === "sessions"}
  <SessionsScreen {monday} {today} {sessions} {status} onback={() => (view = "week")} onadd={openNew} />
{:else}
  <WeekScreen
    {monday}
    {today}
    {sessions}
    {status}
    {atCurrent}
    loggingOut={logoutMutation.isPending}
    {logoutError}
    onprevious={previous}
    onnext={next}
    onadd={openNew}
    onsessions={() => (view = "sessions")}
    onlogout={onLogout}
  />
{/if}
