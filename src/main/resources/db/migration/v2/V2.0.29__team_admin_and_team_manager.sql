alter table team
    rename column manager_id to admin_id;

create table team_managers
(
    id            CHAR(36) NOT NULL PRIMARY KEY,
    team_id       BIGINT   not null,
    member_id     BIGINT   not null,
    created_date  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
