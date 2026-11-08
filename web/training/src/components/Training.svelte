<script lang="ts">
  import { onMount } from "svelte";
  import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query";
  import { isUnauthorized } from "../api/client";
  import { identityQueryKey, logout } from "../api/identity";
  import { listSessions, sessionsQueryKey, type LoggedSession } from "../api/sessions";
  import { describeSync, describeSyncFailure, syncGarmin } from "../api/sync";
  import { addDays, mondayOf, todayIso, weekOffset } from "../dates";
  import NewSession from "./NewSession.svelte";
  import SessionsScreen from "./SessionsScreen.svelte";
  import WeekScreen from "./WeekScreen.svelte";

  type View = "week" | "sessions" | "new" | "edit";

  const queryClient = useQueryClient();
  const today = todayIso();
  let offset = $state(0);
  let view = $state<View>("week");
  let returnTo = $state<"week" | "sessions">("week");
  let editing = $state<LoggedSession | null>(null);
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

  function openEdit(session: LoggedSession) {
    returnTo = view === "sessions" ? "sessions" : "week";
    editing = session;
    view = "edit";
  }

  function closeForm() {
    editing = null;
    view = returnTo;
    window.scrollTo(0, 0);
  }

  function saved(onDate: string) {
    offset = Math.min(0, weekOffset(mondayOf(today), mondayOf(onDate)));
    editing = null;
    view = returnTo;
    window.scrollTo(0, 0);
    void queryClient.invalidateQueries({ queryKey: sessionsQueryKey });
  }

  function deleted() {
    const removed = editing;
    if (removed) {
      queryClient.setQueryData<LoggedSession[]>(
        [...sessionsQueryKey, "week", monday],
        (current) => current?.filter((session) => session.id !== removed.id),
      );
    }
    editing = null;
    view = "week";
    window.scrollTo(0, 0);
    void queryClient.invalidateQueries({ queryKey: sessionsQueryKey });
  }

  function onLogout() {
    if (logoutMutation.isPending) {
      return;
    }
    logoutMutation.mutate();
  }

  const syncMutation = createMutation(() => ({
    mutationFn: syncGarmin,
    onSuccess: (result) => {
      if (result.sessions.length > 0) {
        void queryClient.invalidateQueries({ queryKey: sessionsQueryKey });
      }
    },
  }));

  function onSync() {
    if (syncMutation.isPending) {
      return;
    }
    syncMutation.mutate();
  }

  const syncMessage = $derived.by(() => {
    if (syncMutation.isPending) {
      return "";
    }
    if (syncMutation.isError) {
      return describeSyncFailure(syncMutation.error);
    }
    if (syncMutation.data) {
      return describeSync(syncMutation.data);
    }
    return "";
  });

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
  <NewSession {today} oncancel={closeForm} onsaved={saved} />
{:else if view === "edit" && editing}
  <NewSession {today} session={editing} oncancel={closeForm} onsaved={saved} ondeleted={deleted} />
{:else if view === "sessions"}
  <SessionsScreen
    {monday}
    {today}
    {sessions}
    {status}
    onback={() => (view = "week")}
    onadd={openNew}
    onopen={openEdit}
  />
{:else}
  <WeekScreen
    {monday}
    {today}
    {sessions}
    {status}
    {atCurrent}
    loggingOut={logoutMutation.isPending}
    {logoutError}
    syncing={syncMutation.isPending}
    {syncMessage}
    syncFailed={syncMutation.isError}
    onsync={onSync}
    onprevious={previous}
    onnext={next}
    onadd={openNew}
    onopen={openEdit}
    onsessions={() => (view = "sessions")}
    onlogout={onLogout}
  />
{/if}
