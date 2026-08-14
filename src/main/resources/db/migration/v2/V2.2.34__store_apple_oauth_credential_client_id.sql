ALTER TABLE apple_oauth_credential
    ADD COLUMN client_id VARCHAR(255) NULL AFTER social_id;

DROP INDEX uk_apple_oauth_credential_provider_social
    ON apple_oauth_credential;

ALTER TABLE apple_oauth_credential
    ADD CONSTRAINT uk_apple_oauth_credential_provider_social_client
    UNIQUE (provider, social_id, client_id);
