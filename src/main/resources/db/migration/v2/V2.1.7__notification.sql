CREATE TABLE notifications (
    id CHAR(36) PRIMARY KEY,
    member_id BIGINT NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    reference_type VARCHAR(50),
    reference_id VARCHAR(50),
    actor_id BIGINT,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_date DATETIME NOT NULL,
    modified_date DATETIME NOT NULL,
    INDEX idx_notifications_member_unread (member_id, is_read, created_date DESC),
    INDEX idx_notifications_member_created (member_id, created_date DESC),
    CONSTRAINT fk_notifications_member FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE
);
