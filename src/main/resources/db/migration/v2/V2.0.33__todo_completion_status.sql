ALTER TABLE `todo`
    ADD COLUMN `status` varchar(20) NOT NULL DEFAULT 'ACTIVE' AFTER `position`,
    ADD COLUMN `completed_date` datetime NULL AFTER `status`;

ALTER TABLE `todo`
    MODIFY COLUMN `position` int NULL;
