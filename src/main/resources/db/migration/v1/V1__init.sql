CREATE TABLE `d_day_event`
(
    `id`         bigint NOT NULL AUTO_INCREMENT,
    `date`       date         DEFAULT NULL,
    `is_private` bit(1) NOT NULL,
    `position`   bigint NOT NULL,
    `title`      varchar(255) DEFAULT NULL,
    `member_id`  bigint       DEFAULT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `department`
(
    `id`                 bigint NOT NULL AUTO_INCREMENT,
    `name`               varchar(255) DEFAULT NULL,
    `off_color`          varchar(255) DEFAULT NULL,
    `created_date`       datetime(6)  DEFAULT NULL,
    `last_modified_date` datetime(6)  DEFAULT NULL,
    `description`        varchar(255) DEFAULT NULL,
    `manager_id`         bigint       DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE (`name`)
);

CREATE TABLE `duty`
(
    `id`           bigint NOT NULL AUTO_INCREMENT,
    `duty_day`     int    NOT NULL,
    `duty_month`   int    NOT NULL,
    `duty_year`    int    NOT NULL,
    `memo`         varchar(255) DEFAULT NULL,
    `duty_type_id` bigint       DEFAULT NULL,
    `member_id`    bigint       DEFAULT NULL,
    PRIMARY KEY (`id`)
);


CREATE TABLE `duty_type`
(
    `id`            bigint NOT NULL AUTO_INCREMENT,
    `color`         varchar(255) DEFAULT NULL,
    `name`          varchar(255) DEFAULT NULL,
    `position`      int    NOT NULL,
    `department_id` bigint       DEFAULT NULL,
    PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `holiday`;
CREATE TABLE `holiday`
(
    `id`         char(36)    NOT NULL,
    `date_name`  varchar(50) NOT NULL,
    `is_holiday` bit(1)      NOT NULL,
    `local_date` date        NOT NULL,
    PRIMARY KEY (`id`)
);

DROP TABLE IF EXISTS `member`;
CREATE TABLE `member`
(
    `id`            bigint       NOT NULL AUTO_INCREMENT,
    `name`          varchar(255) DEFAULT NULL,
    `password`      varchar(255) DEFAULT NULL,
    `department_id` bigint       DEFAULT NULL,
    `email`         varchar(255) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE (`name`)
);

CREATE TABLE `refresh_token`
(
    `id`                 bigint NOT NULL AUTO_INCREMENT,
    `created_date`       datetime(6)  DEFAULT NULL,
    `modified_date`      datetime(6)  DEFAULT NULL,
    `refresh_token`      varchar(255) DEFAULT NULL,
    `valid_until`        datetime(6)  DEFAULT NULL,
    `member_id`          bigint       DEFAULT NULL,
    `remote_addr`        varchar(255) DEFAULT NULL,
    `user_agent`         varchar(255) DEFAULT NULL,
    `last_used`          datetime(6)  DEFAULT NULL,
    `last_modified_date` datetime(6)  DEFAULT NULL,
    PRIMARY KEY (`id`)
);


CREATE TABLE `schedule`
(
    `id`              char(36)    NOT NULL,
    `content`         varchar(50) NOT NULL,
    `end_date_time`   datetime(6) NOT NULL,
    `position`        int         NOT NULL,
    `start_date_time` datetime(6) NOT NULL,
    `member_id`       bigint      NOT NULL,
    PRIMARY KEY (`id`)
);
