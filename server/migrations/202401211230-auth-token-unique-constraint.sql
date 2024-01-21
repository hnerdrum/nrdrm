ALTER TABLE "auth_token"
ADD CONSTRAINT unique_auth_token_value_user_id UNIQUE ("value", "user_id");