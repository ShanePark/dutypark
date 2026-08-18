CREATE TABLE member_block
(
    id            CHAR(36)    NOT NULL PRIMARY KEY,
    blocker_id    BIGINT      NOT NULL,
    blocked_id    BIGINT      NOT NULL,
    created_date  DATETIME(6) NOT NULL,
    modified_date DATETIME(6) NOT NULL,
    CONSTRAINT uk_member_block_pair UNIQUE (blocker_id, blocked_id),
    CONSTRAINT fk_member_block_blocker FOREIGN KEY (blocker_id) REFERENCES member (id) ON DELETE CASCADE,
    CONSTRAINT fk_member_block_blocked FOREIGN KEY (blocked_id) REFERENCES member (id) ON DELETE CASCADE
);

CREATE INDEX idx_member_block_blocked ON member_block (blocked_id);
