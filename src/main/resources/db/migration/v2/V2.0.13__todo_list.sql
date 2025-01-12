CREATE TABLE `todo`
(
    `id`            char(36) PRIMARY KEY,
    `member_id`     bigint NOT NULL,
    `title`         varchar(50) NOT NULL,
    `content`       varchar(50) NOT NULL,
    `position`      int NOT NULL,
    `created_date`  datetime NOT NULL,
    `modified_date` datetime NOT NULL,

    index `idx_member_id` (`member_id`)
);
