ALTER TABLE department
    RENAME TO team;

alter table duty_type rename column department_id to team_id;
alter table member rename column department_id to team_id;
