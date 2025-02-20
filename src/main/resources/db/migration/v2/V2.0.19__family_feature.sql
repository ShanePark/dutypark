alter table friends
    add column is_family boolean not null default false;

update schedule
set visibility = 'FAMILY'
where visibility = 'FRIENDS';
