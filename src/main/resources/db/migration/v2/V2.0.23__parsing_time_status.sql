alter table schedule
    add column parsing_time_status varchar(255) default 'WAIT';
