-- Step 1: Migrate status values
-- ACTIVE -> TODO, COMPLETED -> DONE
UPDATE todo SET status = 'TODO' WHERE status = 'ACTIVE';
UPDATE todo SET status = 'DONE' WHERE status = 'COMPLETED';

-- Step 2: Set position for DONE items (currently NULL)
-- Use ROW_NUMBER() window function for MySQL 8.0+
UPDATE todo t
INNER JOIN (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY member_id
            ORDER BY completed_date DESC, id
        ) as new_position
    FROM todo
    WHERE status = 'DONE'
) ranked ON t.id = ranked.id
SET t.position = ranked.new_position
WHERE t.status = 'DONE';

-- Step 3: Normalize TODO positions (ensure sequential from 0)
UPDATE todo t
INNER JOIN (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY member_id
            ORDER BY position ASC, id
        ) - 1 as new_position
    FROM todo
    WHERE status = 'TODO'
) ranked ON t.id = ranked.id
SET t.position = ranked.new_position
WHERE t.status = 'TODO';
