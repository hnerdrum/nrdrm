<script>
	import '../globals.css';
</script>

<style>
  .container {
    max-width: 390px;
    padding: 16px;
  }

  @media (min-width: 768px) {
    .container {
      padding: 2rem;
    }
  }
</style>

<div class="container">
  <slot></slot>
</div>
