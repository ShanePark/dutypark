ALTER TABLE notifications
    ADD COLUMN event_key VARCHAR(120) NULL,
    ADD CONSTRAINT uk_notifications_event_key UNIQUE (event_key);
