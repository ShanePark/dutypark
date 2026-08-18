-- Blocking now removes the tag relationships between the two members, but pairs that were
-- already blocked still carry tags created before the block. Clean them up in both
-- directions: tags on one member's content pointing at the other.
DELETE st
FROM `schedule_tags` st
    JOIN `schedule` s ON s.id = st.schedule_id
    JOIN `member_block` mb
        ON (mb.blocker_id = s.member_id AND mb.blocked_id = st.member_id)
            OR (mb.blocker_id = st.member_id AND mb.blocked_id = s.member_id);

DELETE tt
FROM `todo_tags` tt
    JOIN `todo` t ON t.id = tt.todo_id
    JOIN `member_block` mb
        ON (mb.blocker_id = t.member_id AND mb.blocked_id = tt.member_id)
            OR (mb.blocker_id = tt.member_id AND mb.blocked_id = t.member_id);
