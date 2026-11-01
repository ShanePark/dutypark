ALTER TABLE mobile_oauth_transaction
    ADD COLUMN link_authorized BOOLEAN NOT NULL DEFAULT FALSE;
