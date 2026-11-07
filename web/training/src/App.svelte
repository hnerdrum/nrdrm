<script lang="ts">
  import { onMount } from "svelte";
  import LoginForm from "./components/LoginForm.svelte";
  import SignedIn from "./components/SignedIn.svelte";
  import { currentSession, login, logout } from "./session";

  let screen = $state<"checking" | "login" | "home">("checking");
  let email = $state("");
  let error = $state("");
  let logoutError = $state("");
  let submitting = $state(false);
  let loggingOut = $state(false);

  onMount(() => {
    void restore();
  });

  async function restore() {
    const session = await currentSession();
    screen = session ? "home" : "login";
  }

  async function onLogin(password: string) {
    if (submitting) return;
    submitting = true;
    error = "";
    const result = await login(email, password);
    submitting = false;
    if (result === "ok") {
      screen = "home";
      return;
    }
    error =
      result === "rejected" ? "Wrong email or password." : "Couldn't sign in. Try again.";
  }

  async function onLogout() {
    if (loggingOut) return;
    loggingOut = true;
    logoutError = "";
    const ok = await logout();
    loggingOut = false;
    if (ok) {
      screen = "login";
      return;
    }
    logoutError = "Couldn't log out. Try again.";
  }
</script>

{#if screen === "login"}
  <LoginForm bind:email {error} {submitting} onsubmit={onLogin} />
{:else if screen === "home"}
  <SignedIn {loggingOut} {logoutError} onlogout={onLogout} />
{/if}
