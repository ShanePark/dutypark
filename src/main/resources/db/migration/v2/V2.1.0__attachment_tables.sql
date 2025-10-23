create table attachment_upload_session
(
    `id`                char(36)     not null,
    `context_type`      varchar(50)  not null,
    `target_context_id` varchar(255) null,
    `owner_id`          bigint       not null,
    `expires_at`        datetime(6)  not null,
    `created_date`      datetime(6)  not null,
    `modified_date`     datetime(6)  not null,
    primary key (`id`)
);

create index idx_upload_session_expires_at on attachment_upload_session (`expires_at`);

create table attachment
(
    `id`                     char(36)     not null,
    `context_type`           varchar(50)  not null,
    `context_id`             varchar(255) null,
    `upload_session_id`      char(36)     null,
    `original_filename`      varchar(255) not null,
    `stored_filename`        varchar(255) not null,
    `content_type`           varchar(100) not null,
    `size`                   bigint       not null,
    `storage_path`           varchar(500) not null,
    `thumbnail_filename`     varchar(255) null,
    `thumbnail_content_type` varchar(100) null,
    `thumbnail_size`         bigint       null,
    `order_index`            int          not null,
    `created_by`             bigint       not null,
    `created_date`           datetime(6)  not null,
    `modified_date`          datetime(6)  not null,
    primary key (`id`)
);

create index idx_attachment_context on attachment (`context_type`, `context_id`);
create index idx_attachment_session on attachment (`upload_session_id`);
