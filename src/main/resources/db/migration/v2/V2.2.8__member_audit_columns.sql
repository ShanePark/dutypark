alter table member
    add column created_date datetime,
    add column modified_date datetime;

update member
set created_date  = now(),
    modified_date = now()
where created_date is null;
