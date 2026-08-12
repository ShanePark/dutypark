ALTER TABLE member
    ADD COLUMN status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
    ADD COLUMN deletion_requested_at DATETIME(6) NULL;

CREATE TABLE account_reauth_proof
(
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    purpose     VARCHAR(30) NOT NULL,
    proof_hash  CHAR(64)    NOT NULL,
    member_id   BIGINT      NOT NULL,
    expires_at  DATETIME(6) NOT NULL,
    consumed_at DATETIME(6) NULL,
    created_at  DATETIME(6) NOT NULL,
    CONSTRAINT uk_account_reauth_proof_hash UNIQUE (proof_hash)
);

CREATE INDEX idx_account_reauth_proof_member_purpose_expiry
    ON account_reauth_proof (member_id, purpose, expires_at);

CREATE TABLE account_deletion_job
(
    id                     BIGINT AUTO_INCREMENT PRIMARY KEY,
    root_member_id         BIGINT       NOT NULL,
    delete_team_id         BIGINT       NULL,
    replacement_manager_id BIGINT       NULL,
    status                 VARCHAR(30)  NOT NULL,
    attempt_count          INT          NOT NULL DEFAULT 0,
    next_attempt_at        DATETIME(6)  NOT NULL,
    locked_at              DATETIME(6)  NULL,
    last_error             TEXT         NULL,
    completed_at           DATETIME(6)  NULL,
    created_at             DATETIME(6)  NOT NULL,
    CONSTRAINT uk_account_deletion_job_root_member UNIQUE (root_member_id)
);

CREATE INDEX idx_account_deletion_job_claim
    ON account_deletion_job (status, next_attempt_at, locked_at);

CREATE TABLE account_deletion_target_member
(
    id        BIGINT AUTO_INCREMENT PRIMARY KEY,
    job_id    BIGINT NOT NULL,
    member_id BIGINT NOT NULL,
    CONSTRAINT uk_account_deletion_target_member UNIQUE (job_id, member_id),
    CONSTRAINT fk_account_deletion_target_member_job
        FOREIGN KEY (job_id) REFERENCES account_deletion_job (id) ON DELETE CASCADE
);

CREATE INDEX idx_account_deletion_target_member_job
    ON account_deletion_target_member (job_id);

CREATE TABLE account_deletion_target_team
(
    id      BIGINT AUTO_INCREMENT PRIMARY KEY,
    job_id  BIGINT NOT NULL,
    team_id BIGINT NOT NULL,
    CONSTRAINT uk_account_deletion_target_team UNIQUE (job_id, team_id),
    CONSTRAINT fk_account_deletion_target_team_job
        FOREIGN KEY (job_id) REFERENCES account_deletion_job (id) ON DELETE CASCADE
);

CREATE INDEX idx_account_deletion_target_team_job
    ON account_deletion_target_team (job_id);
