alter table department
    rename column last_modified_date to modified_date;

alter table refresh_token
    drop column modified_date;
alter table refresh_token
    rename column last_modified_date to modified_date;
