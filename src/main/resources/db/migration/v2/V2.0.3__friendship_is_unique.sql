alter table friends
    add unique idx_friends_member_id_friend_id (member_id, friend_id);
