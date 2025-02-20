alter table friend_requests
    add column request_type varchar(255) not null default 'FRIEND_REQUEST';
