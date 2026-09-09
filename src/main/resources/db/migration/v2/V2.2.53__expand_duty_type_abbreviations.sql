ALTER TABLE duty_type
    DROP CHECK chk_duty_type_abbreviation_format;

ALTER TABLE duty_type
    MODIFY COLUMN abbreviation VARCHAR(3) NULL;

ALTER TABLE duty_type
    ADD CONSTRAINT chk_duty_type_abbreviation_format
        CHECK (abbreviation IS NULL OR REGEXP_LIKE(abbreviation, '^[A-Za-z가-힣]{1,3}$', 'c'));

ALTER TABLE team
    DROP CHECK chk_team_default_duty_abbreviation_format;

ALTER TABLE team
    MODIFY COLUMN default_duty_abbreviation VARCHAR(3) NULL;

ALTER TABLE team
    ADD CONSTRAINT chk_team_default_duty_abbreviation_format
        CHECK (default_duty_abbreviation IS NULL OR REGEXP_LIKE(default_duty_abbreviation, '^[A-Za-z가-힣]{1,3}$', 'c'));
