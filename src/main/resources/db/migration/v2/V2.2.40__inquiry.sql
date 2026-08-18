CREATE TABLE inquiry
(
    id             CHAR(36)      NOT NULL PRIMARY KEY,
    member_id      BIGINT        NULL,
    email          VARCHAR(255)  NOT NULL,
    subject        VARCHAR(100)  NULL,
    content        VARCHAR(2000) NOT NULL,
    ip_address     VARCHAR(45)   NOT NULL,
    status         VARCHAR(20)   NOT NULL,
    admin_memo     VARCHAR(1000) NULL,
    closed_at      DATETIME(6)   NULL,
    closed_by      BIGINT        NULL,
    created_date   DATETIME(6)   NOT NULL,
    modified_date  DATETIME(6)   NOT NULL,
    CONSTRAINT fk_inquiry_member FOREIGN KEY (member_id) REFERENCES member (id) ON DELETE SET NULL
);

CREATE INDEX idx_inquiry_status_created ON inquiry (status, created_date);
CREATE INDEX idx_inquiry_ip_created ON inquiry (ip_address, created_date);
