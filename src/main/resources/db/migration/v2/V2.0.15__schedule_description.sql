ALTER TABLE schedule
    ADD COLUMN description text;

update schedule
set description = ''
where description is null;
