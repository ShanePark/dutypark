CREATE TABLE apns_installation
(
    id            CHAR(36)     PRIMARY KEY,
    member_id     BIGINT       NOT NULL,
    device_token  VARCHAR(512) NOT NULL,
    created_date  DATETIME(6)  NOT NULL,
    modified_date DATETIME(6)  NOT NULL,
    CONSTRAINT uk_apns_installation_device_token UNIQUE (device_token),
    CONSTRAINT fk_apns_installation_member FOREIGN KEY (member_id) REFERENCES member (id) ON DELETE CASCADE
);

CREATE INDEX idx_apns_installation_member ON apns_installation (member_id);
