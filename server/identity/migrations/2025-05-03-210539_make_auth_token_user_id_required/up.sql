DELETE FROM auth_token WHERE user_id IS NULL;

ALTER TABLE auth_token ALTER COLUMN user_id SET NOT NULL;