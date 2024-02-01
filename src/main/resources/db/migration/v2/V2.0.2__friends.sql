create table `friends`
(
    `id`            bigint      NOT NULL AUTO_INCREMENT,
    `member_id`     int(11)     NOT NULL,
    `friend_id`     int(11)     NOT NULL,
    `created_date`  datetime(6) NOT NULL,
    `modified_date` datetime(6) NOT NULL,
    PRIMARY KEY (`id`)
);

alter table friends
    add index idx_friends_member_id (member_id);
alter table friends
    add index idx_friends_friend_id (friend_id);


