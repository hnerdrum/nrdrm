<script lang="ts">
  type Props = {
    id: string;
    label: string;
    type?: "text" | "email" | "password" | "date";
    name?: string;
    autocomplete?: HTMLInputElement["autocomplete"];
    inputmode?: "decimal" | "numeric" | "text";
    max?: string;
    placeholder?: string;
    large?: boolean;
    mono?: boolean;
    value?: string;
    element?: HTMLInputElement | null;
    onkeydown?: (event: KeyboardEvent) => void;
  };

  let {
    id,
    label,
    type = "text",
    name,
    autocomplete,
    inputmode,
    max,
    placeholder,
    large = false,
    mono = false,
    value = $bindable(""),
    element = $bindable(null),
    onkeydown,
  }: Props = $props();

  const fieldClass = $derived(
    [
      "w-full border border-edge px-4 text-fg transition-[border-color] hover:border-muted focus-visible:border-accent focus-visible:outline-offset-1",
      large
        ? "min-h-[68px] rounded-[18px] bg-field text-[2rem] font-normal tracking-[-0.03em]"
        : "min-h-[52px] rounded-2xl bg-field",
      mono ? "font-mono tabular-nums" : "",
    ].join(" "),
  );
</script>

<label class="grid gap-2" for={id}>
  <span class="text-muted">{label}</span>
  <input
    {id}
    {type}
    {name}
    {autocomplete}
    {inputmode}
    {max}
    {placeholder}
    {onkeydown}
    bind:this={element}
    bind:value
    class={fieldClass}
  />
</label>
