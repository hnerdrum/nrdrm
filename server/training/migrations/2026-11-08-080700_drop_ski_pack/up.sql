UPDATE "session"
SET "body" = "body" - 'withPack'
WHERE "body"->>'sport' = 'ski';
