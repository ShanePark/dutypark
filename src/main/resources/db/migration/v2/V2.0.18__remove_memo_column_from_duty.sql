ALTER TABLE duty
    DROP COLUMN memo;

delete
from duty
where duty_type_id is null;
