CREATE TABLE apple_oauth_credential (
    id BIGINT NOT NULL AUTO_INCREMENT,
    provider VARCHAR(20) NOT NULL,
    social_id VARCHAR(255) NOT NULL,
    encrypted_refresh_token TEXT NOT NULL,
    created_at DATETIME(6) NOT NULL,
    updated_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_apple_oauth_credential_provider_social UNIQUE (provider, social_id)
);

CREATE TABLE apple_identity_token_replay (
    id BIGINT NOT NULL AUTO_INCREMENT,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME(6) NOT NULL,
    created_at DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uk_apple_identity_token_replay_hash UNIQUE (token_hash),
    INDEX idx_apple_identity_token_replay_expires (expires_at)
);
