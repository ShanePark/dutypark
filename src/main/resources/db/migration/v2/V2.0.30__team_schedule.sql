create table team_schedule
(
    `id`               char(36)    not null,
    `created_date`     datetime    not null DEFAULT CURRENT_TIMESTAMP,
    `modified_date`    datetime    not null DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `team_id`          bigint      not null,
    `create_member_id` bigint      not null,
    `update_member_id` bigint      not null,
    `content`          varchar(50) not null,
    `description`      text,
    `start_date_time`  datetime    not null,
    `end_date_time`    datetime    not null,
    `position`         int         not null,
    PRIMARY KEY (`id`),

    INDEX idx_team_id (`team_id`),
    INDEX idx_schedule_period (`start_date_time`, `end_date_time`)
);
