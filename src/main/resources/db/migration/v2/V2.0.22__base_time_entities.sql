alter table holiday
    add column created_date  datetime,
    add column modified_date datetime;

update holiday
set created_date  = now(),
    modified_date = now()
where created_date is null;

alter table schedule
    add column created_date  datetime,
    add column modified_date datetime;

update schedule
set created_date  = now(),
    modified_date = now()
where created_date is null;
