CREATE TABLE mobile_oauth_transaction
(
    id                     BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider               VARCHAR(20)  NOT NULL,
    purpose                VARCHAR(20)  NOT NULL,
    callback_uri           VARCHAR(500) NOT NULL,
    code_challenge         VARCHAR(128) NOT NULL,
    state_hash             CHAR(64)     NOT NULL,
    state_expires_at       DATETIME(6)  NOT NULL,
    link_member_id         BIGINT       NULL,
    state_consumed_at      DATETIME(6)  NULL,
    exchange_code_hash     CHAR(64)     NULL,
    exchange_expires_at    DATETIME(6)  NULL,
    exchange_consumed_at   DATETIME(6)  NULL,
    member_id              BIGINT       NULL,
    signup_uuid            VARCHAR(36)  NULL,
    CONSTRAINT uk_mobile_oauth_state_hash UNIQUE (state_hash),
    CONSTRAINT uk_mobile_oauth_exchange_code_hash UNIQUE (exchange_code_hash),
    CONSTRAINT fk_mobile_oauth_link_member FOREIGN KEY (link_member_id) REFERENCES member (id) ON DELETE CASCADE,
    CONSTRAINT fk_mobile_oauth_member FOREIGN KEY (member_id) REFERENCES member (id) ON DELETE CASCADE
);

CREATE INDEX idx_mobile_oauth_state_expiry ON mobile_oauth_transaction (state_expires_at);
CREATE INDEX idx_mobile_oauth_exchange_expiry ON mobile_oauth_transaction (exchange_expires_at);
