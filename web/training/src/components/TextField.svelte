<script lang="ts">
  type Props = {
    id: string;
    label: string;
    type?: "text" | "email" | "password";
    name?: string;
    autocomplete?: HTMLInputElement["autocomplete"];
    value?: string;
    element?: HTMLInputElement | null;
  };

  let {
    id,
    label,
    type = "text",
    name,
    autocomplete,
    value = $bindable(""),
    element = $bindable(null),
  }: Props = $props();
</script>

<label class="grid gap-2" for={id}>
  <span class="text-muted">{label}</span>
  <input
    {id}
    {type}
    {name}
    {autocomplete}
    bind:this={element}
    bind:value
    class="min-h-[52px] w-full rounded-2xl border border-edge bg-field px-4 text-fg transition-[border-color] hover:border-muted focus-visible:border-accent focus-visible:outline-offset-1"
  />
</label>
