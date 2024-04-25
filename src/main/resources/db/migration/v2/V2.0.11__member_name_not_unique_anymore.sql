ALTER TABLE `member`
    DROP INDEX `name`;

ALTER TABLE `member`
    MODIFY COLUMN `name` varchar (255) DEFAULT NULL;

ALTER TABLE `member`
    ADD INDEX `idx_member_name` (`name`);
