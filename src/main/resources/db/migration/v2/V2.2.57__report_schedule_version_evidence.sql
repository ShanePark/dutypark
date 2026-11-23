ALTER TABLE content_report
    ADD COLUMN schedule_version BIGINT NULL,
    ADD COLUMN schedule_evidence LONGTEXT NULL;

CREATE INDEX idx_content_report_schedule_version
    ON content_report (reporter_id, target_type, target_id, schedule_version, status);
