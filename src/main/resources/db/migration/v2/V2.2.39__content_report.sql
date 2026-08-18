CREATE TABLE content_report
(
    id                   CHAR(36)      NOT NULL PRIMARY KEY,
    reporter_id          BIGINT        NULL,
    reported_member_id   BIGINT        NULL,
    target_type          VARCHAR(20)   NOT NULL,
    target_id            VARCHAR(36)   NOT NULL,
    reason               VARCHAR(30)   NOT NULL,
    detail               VARCHAR(500)  NULL,
    content_snapshot     TEXT          NOT NULL,
    reporter_name        VARCHAR(50)   NOT NULL,
    reported_member_name VARCHAR(50)   NOT NULL,
    status               VARCHAR(20)   NOT NULL,
    admin_memo           VARCHAR(1000) NULL,
    resolved_at          DATETIME(6)   NULL,
    resolved_by          BIGINT        NULL,
    created_date         DATETIME(6)   NOT NULL,
    modified_date        DATETIME(6)   NOT NULL,
    CONSTRAINT fk_content_report_reporter FOREIGN KEY (reporter_id) REFERENCES member (id) ON DELETE SET NULL,
    CONSTRAINT fk_content_report_reported FOREIGN KEY (reported_member_id) REFERENCES member (id) ON DELETE SET NULL
);

CREATE INDEX idx_content_report_status_created ON content_report (status, created_date);
CREATE INDEX idx_content_report_reporter_target ON content_report (reporter_id, target_type, target_id);
