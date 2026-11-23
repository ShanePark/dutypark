ALTER TABLE schedule
    ADD COLUMN revision_version BIGINT NOT NULL DEFAULT 0,
    ADD COLUMN created_by_id BIGINT NULL,
    ADD COLUMN created_by_name VARCHAR(50) NULL,
    ADD COLUMN last_edited_by_id BIGINT NULL,
    ADD COLUMN last_edited_by_name VARCHAR(50) NULL,
    ADD COLUMN last_edited_at DATETIME(6) NULL;

CREATE TABLE schedule_revision
(
    id            CHAR(36)    NOT NULL PRIMARY KEY,
    schedule_id   CHAR(36)    NOT NULL,
    version       BIGINT      NOT NULL,
    actor_id      BIGINT      NULL,
    actor_name    VARCHAR(50) NULL,
    source        VARCHAR(20) NOT NULL,
    snapshot_json LONGTEXT    NOT NULL,
    created_date  DATETIME(6) NOT NULL,
    modified_date DATETIME(6) NOT NULL,
    CONSTRAINT uk_schedule_revision_version UNIQUE (schedule_id, version),
    CONSTRAINT fk_schedule_revision_schedule FOREIGN KEY (schedule_id) REFERENCES schedule (id) ON DELETE CASCADE
);
