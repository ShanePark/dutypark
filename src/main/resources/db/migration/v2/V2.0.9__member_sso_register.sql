create table member_sso_register
(
    `id`           bigint       NOT NULL AUTO_INCREMENT,
    `uuid`         varchar(255) not null,
    `sso_type`     varchar(255) not null,
    `sso_id`       varchar(255) not null,
    `created_date` datetime     not null,
    primary key (`id`)
);
