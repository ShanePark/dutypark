CREATE TABLE `schedule_tags`
(
    `id`            int auto_increment primary key,
    `schedule_id`   char(36) not null,
    `member_id`     bigint   not null,
    `created_date`  datetime NOT NULL,
    `modified_date` datetime NOT NULL,

    index           `idx_schedule_id` (`schedule_id`),
    index           `idx_member_id` (`member_id`)
)

