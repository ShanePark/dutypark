ALTER TABLE inquiry
    ADD COLUMN answer      VARCHAR(2000) NULL,
    ADD COLUMN answered_at DATETIME(6)   NULL,
    ADD COLUMN answered_by BIGINT        NULL;

CREATE INDEX idx_inquiry_member_created ON inquiry (member_id, created_date);
