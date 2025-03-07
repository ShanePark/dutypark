CREATE TABLE member_manager
(
    id            CHAR(36)     NOT NULL PRIMARY KEY,
    manager_id    BIGINT       NOT NULL,
    managed_id    BIGINT       NOT NULL,
    role          VARCHAR(255) NOT NULL,
    created_date  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_date DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
