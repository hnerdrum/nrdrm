# ORM

A Haskell library for Postgres-backed apps: you write a **Schema**, run **Codegen** to produce table types and a **Client**, then query and write through that Client at runtime.

## Schema → Codegen → Client

### 1. Write a Schema

A Schema is ordinary Haskell — a value built with the Codegen builder API (`ORM.Codegen.Schema`). It describes models, fields, relations, includes, and unique constraints. The canonical example lives in `ORM.Codegen.Spec.Example`:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module ORM.Codegen.Spec.Example where

import ORM.Codegen.Schema

exampleSchema :: Schema
exampleSchema =
  schema [] [taskModel] [] []

taskModel :: Model
taskModel =
  model
    "Task"
    [ uuid "id" & pk & withDefault DefaultUuidV4,
      timestamptz "createdAt" & withDefault DefaultNow,
      timestamptz "updatedAt" & withDefault DefaultNow & updatedAt,
      text "title",
      bool "done"
    ]
    []
```

Table and column names default from the model and field names (`Task` → `task`, `createdAt` → `created_at`). Override with `& table "…"` or `& column "…"` when needed.

Larger apps add enums, relations, `includeGraph` for nested reads, and `unique_` for composite lookups. The recipes app (`ORM.Codegen.Spec.Recipe`) is the full-featured reference.

### 2. Run Codegen

Codegen reads your Schema value and writes generated modules: table/row types under a Schema prefix, optional Include modules, and Client modules when configured.

**The app owns the Schema target.** Codegen is a library (`orm-codegen`); each app supplies a thin executable that points at its targets. In recipes:

```haskell
-- tools/orm-codegen/Main.hs
import ORM.Codegen.CLI (mainWith)
import ORM.Codegen.RecipeTarget (prodTarget)
import ORM.Codegen.Target (testTarget)

main :: IO ()
main = mainWith [testTarget, prodTarget] [prodTarget]
```

A `CodegenTarget` bundles one or more Schemas with output layout (module prefix, directories) and whether to emit Clients. Regenerate from the app directory:

```bash
make orm-gen          # write generated files
make orm-gen-check    # fail if generated files are stale (--check)
make orm-schema-check # compare Schema to live Postgres (--check-schema)
```

CLI flags:

| Flag                 | Purpose                                                                           |
| -------------------- | --------------------------------------------------------------------------------- |
| _(none)_             | Validate Schemas and write all generated outputs                                  |
| `--check`            | Exit non-zero if generated files on disk differ from what Codegen would write     |
| `--check-schema`     | Connect to Postgres (`DATABASE_URL` or `TEST_DATABASE_URL`) and fail on **drift** |
| `--check-migrations` | Alias for `--check-schema`                                                        |
| `--list`             | Print output paths without writing                                                |

Generated Client and Schema modules stay in the consuming app (e.g. recipes writes to `.orm-gen/ORM/…`). Runtime (`orm`) is imported by both generated code and hand-written domain logic.

### 3. Query with the Client

Codegen emits a per-model Client with `create`, `update`, `delete`, and read helpers. Every read takes one **query record** — `where_`, `orderBy_`, `limit_`, `offset_`, optional `select_`, and (for models with Includes) `include_`.

For the Task model above, Codegen emits `ORM.Client.Task`:

```haskell
import qualified ORM.Client.Task as Task
import ORM.Db (Db)
import ORM.Where (eq)

listOpenTasks :: Db [TaskRow]
listOpenTasks =
  Task.findMany
    Task.emptyQuery {Task.where_ = Just (eq Task.taskDone False)}

getTask :: UUID -> Db (Either ORMError TaskRow)
getTask id =
  Task.findUniqueOrFail
    Task.emptyQuery {Task.where_ = Just (eq Task.taskId id)}
```

Models with Includes pass a combinator on the same record (recipes example):

```haskell
Recipe.findMany Recipe.emptyQuery {Recipe.include_ = Recipe.ingredients Recipe.ingredient}
```

Writes keep a separate Include argument for the returned shape: `create include data`.

`findUnique` / `findUniqueOrFail` require a `where_` that matches exactly one row — primary key or a unique constraint declared on the Schema. Incomplete or ambiguous filters return `InvalidUniqueInput`.

## Drift-check and migrations

**The Schema is the source of truth** for what Postgres should look like. Codegen does not run migrations.

1. **Hand-written SQL migrations** change the database.
2. **`--check-schema`** introspects live Postgres and reports drift: missing/extra tables or columns, wrong types or nullability, primary keys, uniques, enums.
3. Fix drift by updating either the Schema or the migrations — whichever side is wrong — then re-run checks.

Typical CI: `make orm-gen-check` ensures committed generated code matches the Schema; `make orm-schema-check` (with a test database) ensures the Schema matches Postgres after migrations.

## Scope and limits

- **No built-in migration handling**
- **Postgres only**
- **No relation filters** — `where_` applies to the root model, not nested relations.
- **No filtered Includes** — Include trees are fixed presets declared on the Schema.
- **Includes are Schema-declared** — nested read shapes are compiled from `includeGraph` or explicit Include trees.
- **String-backed SQL** — queries are assembled as text with bound parameters
- **Limited scalars** — currently only support uuid, text, int, bool, timestamptz, and Schema-defined enums.
