CREATE TABLE login_attempt
(
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    ip_address    VARCHAR(45)  NOT NULL,
    email         VARCHAR(255) NOT NULL,
    attempt_time  DATETIME     NOT NULL,
    success       BOOLEAN      NOT NULL DEFAULT FALSE,
    created_date  DATETIME     NOT NULL,
    modified_date DATETIME     NOT NULL,
    INDEX idx_login_attempt_ip_email_time (ip_address, email, attempt_time),
    INDEX idx_login_attempt_cleanup (attempt_time)
);
