ALTER TABLE member_duty_pattern_weekday
    ADD COLUMN duty_type_id BIGINT NULL AFTER weekday;

UPDATE member_duty_pattern_weekday pattern_day
    JOIN member_duty_pattern pattern ON pattern.id = pattern_day.pattern_id
SET pattern_day.duty_type_id = pattern.duty_type_id;

ALTER TABLE member_duty_pattern_weekday
    MODIFY duty_type_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_member_duty_pattern_weekday_duty_type
        FOREIGN KEY (duty_type_id) REFERENCES duty_type (id),
    ADD INDEX idx_member_duty_pattern_weekday_duty_type (duty_type_id);

ALTER TABLE member_duty_pattern
    DROP FOREIGN KEY fk_member_duty_pattern_duty_type,
    DROP COLUMN duty_type_id;
