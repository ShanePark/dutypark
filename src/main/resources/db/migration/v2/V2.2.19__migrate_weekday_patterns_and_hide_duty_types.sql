ALTER TABLE duty_type
    ADD COLUMN hidden BIT NOT NULL DEFAULT 0 AFTER color,
    ADD INDEX idx_duty_type_team_hidden (team_id, hidden);

SET @pattern_effective_month = DATE_FORMAT(
        CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+09:00'),
        '%Y-%m-01'
                               );

INSERT INTO member_duty_pattern (
    member_id,
    team_id,
    duty_type_id,
    holiday_off,
    effective_from,
    effective_until_exclusive
)
SELECT m.id,
       t.id,
       MIN(dt.id),
       1,
       @pattern_effective_month,
       NULL
FROM member m
         JOIN team t ON t.id = m.team_id
         JOIN duty_type dt ON dt.team_id = t.id AND dt.hidden = 0
WHERE t.work_type = 'WEEKDAY'
GROUP BY m.id, t.id
HAVING COUNT(dt.id) = 1;

INSERT INTO member_duty_pattern_weekday (pattern_id, weekday)
SELECT p.id, weekdays.weekday
FROM member_duty_pattern p
         CROSS JOIN (
    SELECT 'MONDAY' AS weekday
    UNION ALL SELECT 'TUESDAY'
    UNION ALL SELECT 'WEDNESDAY'
    UNION ALL SELECT 'THURSDAY'
    UNION ALL SELECT 'FRIDAY'
) weekdays
WHERE p.effective_from = @pattern_effective_month;

INSERT INTO member_duty_pattern_month_lock (member_id, team_id, month_start, pattern_id)
SELECT DISTINCT p.member_id,
                p.team_id,
                DATE_FORMAT(d.duty_date, '%Y-%m-01'),
                p.id
FROM member_duty_pattern p
         JOIN duty d ON d.member_id = p.member_id
WHERE p.effective_from = @pattern_effective_month
  AND d.duty_date >= @pattern_effective_month
  AND NOT (
    d.duty_type_id <=> CASE
        WHEN WEEKDAY(d.duty_date) < 5
            AND NOT EXISTS (
                SELECT 1
                FROM holiday h
                WHERE h.local_date = d.duty_date
                  AND h.is_holiday = 1
            )
            THEN p.duty_type_id
        ELSE NULL
    END
  );

INSERT INTO member_duty_pattern_month_lock_workday (lock_id, duty_date)
WITH RECURSIVE day_numbers AS (
    SELECT 0 AS day_offset
    UNION ALL
    SELECT day_offset + 1
    FROM day_numbers
    WHERE day_offset < 30
)
SELECT l.id,
       DATE_ADD(l.month_start, INTERVAL day_numbers.day_offset DAY)
FROM member_duty_pattern_month_lock l
         JOIN member_duty_pattern p ON p.id = l.pattern_id
         CROSS JOIN day_numbers
WHERE DATE_ADD(l.month_start, INTERVAL day_numbers.day_offset DAY) <= LAST_DAY(l.month_start)
  AND WEEKDAY(DATE_ADD(l.month_start, INTERVAL day_numbers.day_offset DAY)) < 5
  AND NOT EXISTS (
    SELECT 1
    FROM holiday h
    WHERE h.local_date = DATE_ADD(l.month_start, INTERVAL day_numbers.day_offset DAY)
      AND h.is_holiday = 1
  );

DELETE d
FROM duty d
         JOIN member_duty_pattern p
              ON p.member_id = d.member_id
                  AND p.effective_from = @pattern_effective_month
         LEFT JOIN member_duty_pattern_month_lock l
                   ON l.member_id = d.member_id
                       AND l.month_start = DATE_FORMAT(d.duty_date, '%Y-%m-01')
WHERE d.duty_date >= @pattern_effective_month
  AND l.id IS NULL;

ALTER TABLE team
    DROP COLUMN work_type;
