CREATE TABLE member_consent (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    policy_type VARCHAR(50) NOT NULL,
    consent_version VARCHAR(20) NOT NULL,
    consented_at DATETIME NOT NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    CONSTRAINT fk_member_consent_member FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE,
    INDEX idx_member_consent_member_type (member_id, policy_type)
);
