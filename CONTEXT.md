# Recipes

Postgres-backed recipe API. Persistence goes through [Poppy](https://github.com/hnerdrum/poppy): this app owns the Schema, a thin codegen executable, and the generated Client.

## Language

**Schema**:
The Haskell description of models, relations, and unique constraints. It is the input to codegen and the source of truth for the Client. You write it as a builder (tables, columns, relations), not as `data` types.
_Avoid_: persist models, schema.prisma, entity defs, row types as authoring

**Client**:
The generated per-model API used by application code to query and write.
_Avoid_: query builder, repository, DAO

**Include**:
A query-time combinator tree — one function per relation — passed as `include_` on the query record. Writes take the same combinator as the returned shape. The Client result type is the named ADT for that tree.
_Avoid_: join, eager load, populate, preset, includeGraph

**Codegen**:
The tool that turns a Schema into table types and a Client.
_Avoid_: Template Haskell splice, persist quasi-quoter

**Runtime**:
The library the generated Client (and hand-written code) calls at query time.
_Avoid_: core, engine, backend

**Drift**:
A mismatch between the Schema and the live Postgres catalog (tables, columns, nullability, keys, uniques, enums).
_Avoid_: migration, schema diff
