alter table member
    add column `calendar_visibility` varchar(255) not null default 'FRIENDS';

alter table schedule
    add column `visibility` varchar(255) not null default 'FRIENDS';

alter table schedule
    add index `visibility` (`visibility`);

