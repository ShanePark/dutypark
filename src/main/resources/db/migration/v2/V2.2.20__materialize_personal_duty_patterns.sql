ALTER TABLE duty
    ADD COLUMN manual_override BIT NOT NULL DEFAULT 1;

DROP TABLE member_duty_pattern_month_lock_workday;
DROP TABLE member_duty_pattern_month_lock;
