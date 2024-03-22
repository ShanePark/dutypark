-- email column allow null
alter table member
    modify email varchar(255) default null;
