ALTER TABLE attachment
    ADD COLUMN thumbnail_status VARCHAR(20) NOT NULL DEFAULT 'NONE';

CREATE INDEX idx_attachment_thumbnail_status ON attachment(thumbnail_status);
