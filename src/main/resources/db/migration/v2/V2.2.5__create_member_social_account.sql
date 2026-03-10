CREATE TABLE member_social_account
(
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id    BIGINT       NOT NULL,
    provider     VARCHAR(255) NOT NULL,
    social_id    VARCHAR(255) NOT NULL,
    created_date DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_member_social_account_member
        FOREIGN KEY (member_id) REFERENCES member (id),
    CONSTRAINT uk_member_social_account_provider_social_id
        UNIQUE (provider, social_id),
    CONSTRAINT uk_member_social_account_member_provider
        UNIQUE (member_id, provider)
);
