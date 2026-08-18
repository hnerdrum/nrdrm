# ORM

A Haskell library: you write a Schema, generate a Client, then query and write through that Client.

## Language

**Schema**:
The Haskell description of models, relations, includes, and unique constraints. It is the input to codegen and the source of truth for the Client. You write it as a builder (tables, columns, relations), not as `data` types.
_Avoid_: persist models, schema.prisma, entity defs, row types as authoring

**Client**:
The generated per-model API used by application code to query and write.
_Avoid_: query builder, repository, DAO

**Include**:
A nested-read tree declared on the Schema and compiled into Client presets (`withIngredients`, `noInclude`). Reads pass it as a field on the query record; writes pass it as the returned shape.
_Avoid_: join, eager load, populate

**Codegen**:
The tool that turns a Schema into table types and a Client.
_Avoid_: Template Haskell splice, persist quasi-quoter

**Runtime**:
The library the generated Client (and hand-written code) calls at query time.
_Avoid_: core, engine, backend

**Drift**:
A mismatch between the Schema and the live Postgres catalog (tables, columns, nullability, keys, uniques, enums).
_Avoid_: migration, schema diff
