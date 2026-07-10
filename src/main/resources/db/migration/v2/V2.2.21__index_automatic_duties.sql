CREATE INDEX idx_duty_automatic_date
    ON duty (manual_override, duty_date);
