<script lang="ts">
  import { loadHealth } from "./health";

  let status = $state("checking");

  async function showHealth() {
    try {
      const health = await loadHealth();
      status = health.status;
    } catch {
      status = "unavailable";
    }
  }

  void showHealth();
</script>

<main>
  <h1>Training</h1>
  <p class="label">Health</p>
  <p class="figure">{status}</p>
</main>
