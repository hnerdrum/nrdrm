ALTER TABLE auth_token
ADD COLUMN issued_at TIMESTAMPTZ,
ADD COLUMN expires_at TIMESTAMPTZ,
DROP COLUMN value;

UPDATE auth_token
SET issued_at = created_at,
    expires_at = created_at + INTERVAL '24 hours';

ALTER TABLE auth_token
ALTER COLUMN issued_at SET NOT NULL,
ALTER COLUMN expires_at SET NOT NULL;