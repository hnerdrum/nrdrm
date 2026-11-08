<script lang="ts">
  import Button from "./Button.svelte";

  type Props = {
    syncing: boolean;
    message: string;
    failed: boolean;
    onsync: () => void;
  };

  let { syncing, message, failed, onsync }: Props = $props();

  function press() {
    if (syncing) {
      return;
    }
    onsync();
  }
</script>

<div class="sync mt-8 flex flex-col items-start gap-3 wide:flex-row wide:items-center wide:gap-5">
  <Button
    variant="outline"
    class="min-w-40 disabled:opacity-100!"
    disabled={syncing}
    onclick={press}
  >
    {syncing ? "Syncing" : "Sync Garmin"}
  </Button>
  {#if message}
    <p class={failed ? "font-medium" : "text-muted"} role={failed ? "alert" : "status"}>{message}</p>
  {/if}
</div>
