CREATE TABLE web_oauth_transaction
(
    id                     BIGINT AUTO_INCREMENT PRIMARY KEY,
    provider               VARCHAR(20)  NOT NULL,
    purpose                VARCHAR(20)  NOT NULL,
    referer                VARCHAR(500) NOT NULL,
    state_hash             CHAR(64)     NOT NULL,
    browser_session_hash   CHAR(64)     NOT NULL,
    state_expires_at       DATETIME(6)  NOT NULL,
    link_member_id         BIGINT       NULL,
    state_consumed_at      DATETIME(6)  NULL,
    CONSTRAINT uk_web_oauth_state_hash UNIQUE (state_hash),
    CONSTRAINT fk_web_oauth_link_member FOREIGN KEY (link_member_id) REFERENCES member (id) ON DELETE CASCADE
);

CREATE INDEX idx_web_oauth_state_expiry ON web_oauth_transaction (state_expires_at);
