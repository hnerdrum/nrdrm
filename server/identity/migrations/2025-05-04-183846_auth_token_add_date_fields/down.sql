ALTER TABLE auth_token
DROP COLUMN issued_at,
DROP COLUMN expires_at,
ADD COLUMN value TEXT;