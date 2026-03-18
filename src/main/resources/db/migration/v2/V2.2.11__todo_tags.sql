CREATE TABLE `todo_tags`
(
    `id`            int auto_increment primary key,
    `todo_id`       char(36) not null,
    `member_id`     bigint   not null,
    `created_date`  datetime NOT NULL,
    `modified_date` datetime NOT NULL,

    index           `idx_todo_tag_todo_id` (`todo_id`),
    index           `idx_todo_tag_member_id` (`member_id`)
);
