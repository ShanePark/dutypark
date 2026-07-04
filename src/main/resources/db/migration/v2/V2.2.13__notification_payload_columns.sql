ALTER TABLE notifications
    ADD COLUMN payload_json JSON NULL AFTER actor_id,
    ADD COLUMN payload_version INT NOT NULL DEFAULT 1 AFTER payload_json;
