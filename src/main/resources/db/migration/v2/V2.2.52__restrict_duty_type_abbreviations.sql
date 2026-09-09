ALTER TABLE duty_type
    ADD CONSTRAINT chk_duty_type_abbreviation_format
        CHECK (abbreviation IS NULL OR REGEXP_LIKE(abbreviation, '^[A-Z가-힣]$', 'c'));

ALTER TABLE duty_type
    MODIFY COLUMN abbreviation VARCHAR(1) NULL;

ALTER TABLE team
    ADD CONSTRAINT chk_team_default_duty_abbreviation_format
        CHECK (default_duty_abbreviation IS NULL OR REGEXP_LIKE(default_duty_abbreviation, '^[A-Z가-힣]$', 'c'));

ALTER TABLE team
    MODIFY COLUMN default_duty_abbreviation VARCHAR(1) NULL;
