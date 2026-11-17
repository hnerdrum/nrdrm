-- A session body's `intervals` (run, ride, ski) and `exercises` (strength)
-- become one ordered `blocks` list, each block tagged by `kind`. Empty lists
-- are left out, as the server writes them. See docs/adr/0002-session-blocks.md.

UPDATE "training_session"
SET "body" = ("body" - 'intervals') || jsonb_build_object('blocks', (
  SELECT jsonb_agg(i.value || '{"kind":"repeats"}' ORDER BY i.ordinality)
  FROM jsonb_array_elements("body"->'intervals') WITH ORDINALITY i))
WHERE jsonb_array_length(COALESCE("body"->'intervals', '[]')) > 0;

UPDATE "training_session"
SET "body" = ("body" - 'exercises') || jsonb_build_object('blocks', (
  SELECT jsonb_agg(e.value || '{"kind":"exercise"}' ORDER BY e.ordinality)
  FROM jsonb_array_elements("body"->'exercises') WITH ORDINALITY e))
WHERE jsonb_array_length(COALESCE("body"->'exercises', '[]')) > 0;

UPDATE "training_session" SET "body" = "body" - 'intervals' - 'exercises'
WHERE "body" ? 'intervals' OR "body" ? 'exercises';

UPDATE "training_preset"
SET "body" = ("body" - 'intervals') || jsonb_build_object('blocks', (
  SELECT jsonb_agg(i.value || '{"kind":"repeats"}' ORDER BY i.ordinality)
  FROM jsonb_array_elements("body"->'intervals') WITH ORDINALITY i))
WHERE jsonb_array_length(COALESCE("body"->'intervals', '[]')) > 0;

UPDATE "training_preset"
SET "body" = ("body" - 'exercises') || jsonb_build_object('blocks', (
  SELECT jsonb_agg(e.value || '{"kind":"exercise"}' ORDER BY e.ordinality)
  FROM jsonb_array_elements("body"->'exercises') WITH ORDINALITY e))
WHERE jsonb_array_length(COALESCE("body"->'exercises', '[]')) > 0;

UPDATE "training_preset" SET "body" = "body" - 'intervals' - 'exercises'
WHERE "body" ? 'intervals' OR "body" ? 'exercises';
