-- Back to `intervals` and `exercises`. This is lossy: steady blocks (warmup,
-- cooldown, ...) have no old shape and are dropped, so a run that had them
-- no longer meets the old rule that its distance and time equal its repeats.
-- Take a dump before migrating up if you may need to come back.

UPDATE "training_session"
SET "body" = ("body" - 'blocks') || jsonb_build_object('intervals', COALESCE((
  SELECT jsonb_agg(b.value - 'kind' ORDER BY b.ordinality)
  FROM jsonb_array_elements("body"->'blocks') WITH ORDINALITY b
  WHERE b.value->>'kind' = 'repeats'), '[]'))
WHERE "body"->>'sport' <> 'strength' AND "body" ? 'blocks';

UPDATE "training_session"
SET "body" = ("body" - 'blocks') || jsonb_build_object('exercises', COALESCE((
  SELECT jsonb_agg(b.value - 'kind' ORDER BY b.ordinality)
  FROM jsonb_array_elements("body"->'blocks') WITH ORDINALITY b
  WHERE b.value->>'kind' = 'exercise'), '[]'))
WHERE "body"->>'sport' = 'strength';

UPDATE "training_session" SET "body" = "body" - 'intervals'
WHERE "body"->'intervals' = '[]';

UPDATE "training_preset"
SET "body" = ("body" - 'blocks') || jsonb_build_object('intervals', COALESCE((
  SELECT jsonb_agg(b.value - 'kind' ORDER BY b.ordinality)
  FROM jsonb_array_elements("body"->'blocks') WITH ORDINALITY b
  WHERE b.value->>'kind' = 'repeats'), '[]'))
WHERE "body"->>'sport' <> 'strength' AND "body" ? 'blocks';

UPDATE "training_preset"
SET "body" = ("body" - 'blocks') || jsonb_build_object('exercises', COALESCE((
  SELECT jsonb_agg(b.value - 'kind' ORDER BY b.ordinality)
  FROM jsonb_array_elements("body"->'blocks') WITH ORDINALITY b
  WHERE b.value->>'kind' = 'exercise'), '[]'))
WHERE "body"->>'sport' = 'strength';

UPDATE "training_preset" SET "body" = "body" - 'intervals'
WHERE "body"->'intervals' = '[]';
