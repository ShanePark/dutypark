CREATE TABLE apns_installation
(
    id               CHAR(36)     PRIMARY KEY,
    refresh_token_id BIGINT       NOT NULL,
    device_token     VARCHAR(512) NOT NULL,
    sandbox          BOOLEAN      NOT NULL DEFAULT FALSE,
    created_date     DATETIME(6)  NOT NULL,
    modified_date    DATETIME(6)  NOT NULL,
    CONSTRAINT uk_apns_installation_device_token UNIQUE (device_token),
    CONSTRAINT fk_apns_installation_refresh_token
        FOREIGN KEY (refresh_token_id) REFERENCES refresh_token (id) ON DELETE CASCADE
);

CREATE INDEX idx_apns_installation_refresh_token ON apns_installation (refresh_token_id);
