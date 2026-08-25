CREATE TABLE create_idempotency_key
(
    id            CHAR(36)    NOT NULL PRIMARY KEY,
    member_id     BIGINT      NOT NULL,
    operation_id  CHAR(36)    NOT NULL,
    resource_kind VARCHAR(30) NOT NULL,
    resource_id   CHAR(36)    NULL,
    created_date  DATETIME(6) NOT NULL,
    modified_date DATETIME(6) NOT NULL,
    CONSTRAINT uk_create_idempotency_member_operation_resource
        UNIQUE (member_id, operation_id, resource_kind),
    CONSTRAINT fk_create_idempotency_member
        FOREIGN KEY (member_id) REFERENCES member (id)
        ON DELETE CASCADE
);

CREATE INDEX idx_create_idempotency_resource
    ON create_idempotency_key (resource_kind, resource_id);
