# A training session is an ordered list of blocks

Status: accepted (2026-11-17). See `.scratch/training-blocks/spec.md`.

A session body used to have one fixed shape per sport: a distance and a time with optional interval repeats whose totals had to equal the session, or a list of exercises. That cannot hold a warmup, a cooldown, or a ride made of differently shaped parts. We replace `intervals` and `exercises` with one ordered list of blocks (`steady`, `repeats`, `exercise`). The sport stays on the body and decides which kinds are allowed.

The session's distance and time stay the truth, because they often come from the watch. Blocks describe structure and may add up to less than the totals, but never more. That replaces the old rule that intervals must equal the totals.

Stored bodies are JSONB, so the change is a hand-written data migration (ADR 0001) over sessions and presets with a hard cutover. We don't read both shapes. The down migration is lossy because it drops steady blocks.

We considered a separate `segments` table and a per-block sport for mixed sessions. We turned both down for now. Bodies are read and written whole, and a ride followed by a run can be logged as two sessions.
