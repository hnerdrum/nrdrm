<script lang="ts">
  import Button from "./Button.svelte";
  import SiteHeader from "./SiteHeader.svelte";

  type Props = {
    loggingOut: boolean;
    logoutError: string;
    onlogout: () => void;
  };

  let { loggingOut, logoutError, onlogout }: Props = $props();
</script>

<div class="enter">
  <SiteHeader>
    <Button variant="quiet" type="button" disabled={loggingOut} onclick={onlogout}>
      Log out
    </Button>
  </SiteHeader>
  {#if logoutError}
    <p class="mx-auto mt-6 max-w-272 font-medium" role="alert">{logoutError}</p>
  {/if}
</div>
