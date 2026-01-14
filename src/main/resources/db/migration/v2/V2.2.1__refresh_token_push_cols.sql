-- Add push notification columns to refresh_token table
ALTER TABLE refresh_token
    ADD COLUMN push_endpoint VARCHAR(500) NULL,
    ADD COLUMN push_p256dh VARCHAR(255) NULL,
    ADD COLUMN push_auth VARCHAR(255) NULL;

-- Unique index for finding tokens by push endpoint
CREATE UNIQUE INDEX idx_refresh_token_push_endpoint ON refresh_token(push_endpoint);
