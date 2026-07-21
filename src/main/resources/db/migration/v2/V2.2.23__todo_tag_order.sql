ALTER TABLE `todo_tags`
    ADD COLUMN `tag_order` int NOT NULL DEFAULT 0;

-- Backfill so existing tagged todos keep their current appearance: they stay above
-- the viewer's own todos (large negative base) in their existing recency order,
-- until the viewer reorders them via drag-and-drop.
-- ROW_NUMBER() returns BIGINT UNSIGNED, so cast to SIGNED before subtracting to
-- avoid an out-of-range error on the negative base.
UPDATE `todo_tags` tt
    JOIN (
        SELECT tag.id AS tag_id,
               CAST(
                   ROW_NUMBER() OVER (
                       PARTITION BY tag.member_id, todo.status
                       ORDER BY todo.modified_date DESC, todo.created_date DESC, todo.id
                   ) AS SIGNED
               ) - 1000000 AS new_order
        FROM `todo_tags` tag
        JOIN `todo` todo ON todo.id = tag.todo_id
    ) ord ON ord.tag_id = tt.id
SET tt.tag_order = ord.new_order;
