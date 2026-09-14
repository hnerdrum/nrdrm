# orm-codegen

Codegen library for the ORM: Schema builder, validation, file emission, Postgres drift-check, and CLI entry points.

The full **Schema → Codegen → Client** walkthrough, drift-check workflow, and scope notes live in [../orm/README.md](../orm/README.md).

## CLI

Apps supply targets and call `ORM.Codegen.CLI.mainWith`:

```haskell
mainWith codegenTargets schemaCheckTargets
```

- First argument: targets whose outputs are written and checked with `--check`.
- Second argument: targets whose Schemas are compared to Postgres with `--check-schema`.

See `ORM.Codegen.Target` and `server/recipes/schema/ORM/Codegen/RecipeTarget.hs` for a production target, and `server/recipes/codegen/Main.hs` for the executable wiring.

## Canonical example

`ORM.Codegen.Spec.Example` is the small Schema referenced in the README. Validate and emit tests in the recipes test suite compile it on every run — the sample stays real without snapshotting README prose.
