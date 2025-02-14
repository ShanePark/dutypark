ALTER TABLE `duty`
    ADD COLUMN `duty_date` DATE DEFAULT NULL;

UPDATE `duty`
SET `duty_date` = STR_TO_DATE(
        CONCAT(duty_year, '-', LPAD(duty_month, 2, '0'), '-', LPAD(duty_day, 2, '0')),
        '%Y-%m-%d'
                  );

ALTER TABLE `duty`
    DROP COLUMN `duty_day`,
    DROP COLUMN `duty_month`,
    DROP COLUMN `duty_year`;

ALTER TABLE `duty`
    ADD INDEX `idx_duty_date` (`duty_date`);
