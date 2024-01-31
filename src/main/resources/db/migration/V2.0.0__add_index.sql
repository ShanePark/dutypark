ALTER TABLE `d_day_event`
    ADD INDEX `idx_d_day_event_date` (`date`);
ALTER TABLE `d_day_event`
    ADD INDEX `idx_d_day_event_is_private` (`is_private`);
ALTER TABLE `d_day_event`
    ADD INDEX `idx_d_day_event_position` (`position`);
ALTER TABLE `d_day_event`
    ADD INDEX `idx_d_day_event_member_id` (`member_id`);

ALTER TABLE `department`
    ADD INDEX `idx_department_manager_id` (`manager_id`);

ALTER TABLE `duty`
    ADD INDEX `idx_duty_duty_year` (`duty_year`);
ALTER TABLE `duty`
    ADD INDEX `idx_duty_duty_month` (`duty_month`);
ALTER TABLE `duty`
    ADD INDEX `idx_duty_duty_day` (`duty_day`);
ALTER TABLE `duty`
    ADD INDEX `idx_duty_member_id` (`member_id`);
ALTER TABLE `duty`
    ADD INDEX `idx_duty_duty_type_id` (`duty_type_id`);

ALTER TABLE `duty_type`
    ADD INDEX `idx_duty_type_position` (`position`);
ALTER TABLE `duty_type`
    ADD INDEX `idx_duty_type_department_id` (`department_id`);

ALTER TABLE `holiday`
    ADD INDEX `idx_holiday_local_date` (`local_date`);

ALTER TABLE `member`
    ADD INDEX `idx_member_department_id` (`department_id`);
ALTER TABLE `member`
    ADD INDEX `idx_member_email` (`email`);

ALTER TABLE `refresh_token`
    ADD INDEX `idx_refresh_token` (`refresh_token`);
ALTER TABLE `refresh_token`
    ADD INDEX `idx_refresh_token_valid_until` (`valid_until`);
ALTER TABLE `refresh_token`
    ADD INDEX `idx_refresh_token_member_id` (`member_id`);
ALTER TABLE `refresh_token`
    ADD INDEX `idx_refresh_token_last_used` (`last_used`);

ALTER TABLE `schedule`
    ADD INDEX `idx_schedule_start_date` (`start_date_time`);
ALTER TABLE `schedule`
    ADD INDEX `idx_schedule_end_date` (`end_date_time`);
ALTER TABLE `schedule`
    ADD INDEX `idx_schedule_position` (`position`);
ALTER TABLE `schedule`
    ADD INDEX `idx_schedule_member_id` (`member_id`);
