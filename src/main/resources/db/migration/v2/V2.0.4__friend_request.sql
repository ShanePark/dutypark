CREATE TABLE `friend_requests`
(
    `id`             int auto_increment primary key,
    `from_member_id` int         not null,
    `to_member_id`   int         not null,
    `status`         varchar(32) not null,
    `created_date`   datetime    NOT NULL,
    `modified_date`  datetime    NOT NULL,

    unique (`from_member_id`, `to_member_id`),
    index `idx_friend_requests_from_member_id` (`from_member_id`),
    index `idx_friend_requests_to_member_id` (`to_member_id`),
    index `idx_friend_requests_status` (`status`)
)
