ALTER TABLE account_deletion_job
    ADD COLUMN receipt_token_hash CHAR(64) NULL,
    ADD COLUMN estimated_completion_at DATETIME(6) NULL,
    ADD COLUMN receipt_expires_at DATETIME(6) NULL,
    ADD COLUMN lease_token VARCHAR(36) NULL;

CREATE UNIQUE INDEX uk_account_deletion_job_receipt_token_hash
    ON account_deletion_job (receipt_token_hash);

CREATE INDEX idx_account_deletion_job_receipt_expiry
    ON account_deletion_job (receipt_expires_at);
