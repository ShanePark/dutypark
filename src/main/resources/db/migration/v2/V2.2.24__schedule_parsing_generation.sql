ALTER TABLE schedule
    ADD COLUMN parsing_generation CHAR(36) NULL AFTER parsing_time_status;

UPDATE schedule
SET parsing_generation = UUID();

ALTER TABLE schedule
    MODIFY COLUMN parsing_generation CHAR(36) NOT NULL;

UPDATE schedule
SET content_without_time = ''
WHERE parsing_time_status IS NULL
   OR parsing_time_status <> 'PARSED';
