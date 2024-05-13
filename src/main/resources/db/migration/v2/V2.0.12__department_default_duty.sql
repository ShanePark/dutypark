ALTER TABLE department
    RENAME COLUMN off_color TO default_duty_color;

ALTER TABLE department
    ADD COLUMN default_duty_name VARCHAR(255) NOT NULL DEFAULT 'OFF';
