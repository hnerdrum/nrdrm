<script lang="ts">
  import * as Card from "$lib/components/ui/card";
  import { Button } from "$lib/components/ui/button";

  export let data;
</script>

<div>
  {#each data.games as game}
    <Card.Root class="mb-2">
      <Card.Header>
        <Card.Title>{game.title}</Card.Title>
      </Card.Header>
      <Card.Content>
        <Button>Se mer</Button>
      </Card.Content>
    </Card.Root>
  {/each}
</div>