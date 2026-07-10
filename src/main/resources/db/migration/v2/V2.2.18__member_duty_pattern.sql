CREATE TABLE member_duty_pattern
(
    id                        BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id                 BIGINT       NOT NULL,
    team_id                   BIGINT       NOT NULL,
    duty_type_id              BIGINT       NOT NULL,
    holiday_off               BIT          NOT NULL DEFAULT 1,
    effective_from            DATE         NOT NULL,
    effective_until_exclusive DATE                  DEFAULT NULL,
    CONSTRAINT fk_member_duty_pattern_member FOREIGN KEY (member_id) REFERENCES member (id),
    CONSTRAINT fk_member_duty_pattern_team FOREIGN KEY (team_id) REFERENCES team (id),
    CONSTRAINT fk_member_duty_pattern_duty_type FOREIGN KEY (duty_type_id) REFERENCES duty_type (id),
    INDEX idx_member_duty_pattern_member_range (member_id, effective_from, effective_until_exclusive)
);

CREATE TABLE member_duty_pattern_weekday
(
    pattern_id BIGINT      NOT NULL,
    weekday    VARCHAR(16) NOT NULL,
    PRIMARY KEY (pattern_id, weekday),
    CONSTRAINT fk_member_duty_pattern_weekday_pattern
        FOREIGN KEY (pattern_id) REFERENCES member_duty_pattern (id) ON DELETE CASCADE
);

CREATE TABLE member_duty_pattern_month_lock
(
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id     BIGINT NOT NULL,
    team_id       BIGINT NOT NULL,
    month_start   DATE   NOT NULL,
    pattern_id    BIGINT DEFAULT NULL,
    CONSTRAINT fk_member_duty_pattern_month_lock_member FOREIGN KEY (member_id) REFERENCES member (id),
    CONSTRAINT fk_member_duty_pattern_month_lock_team FOREIGN KEY (team_id) REFERENCES team (id),
    CONSTRAINT fk_member_duty_pattern_month_lock_pattern FOREIGN KEY (pattern_id) REFERENCES member_duty_pattern (id),
    CONSTRAINT uk_member_duty_pattern_month_lock UNIQUE (member_id, team_id, month_start)
);

CREATE TABLE member_duty_pattern_month_lock_workday
(
    lock_id   BIGINT NOT NULL,
    duty_date DATE   NOT NULL,
    PRIMARY KEY (lock_id, duty_date),
    CONSTRAINT fk_member_duty_pattern_month_lock_workday_lock
        FOREIGN KEY (lock_id) REFERENCES member_duty_pattern_month_lock (id) ON DELETE CASCADE
);

DELETE d1
FROM duty d1
         INNER JOIN duty d2
                    ON d1.member_id = d2.member_id
                        AND d1.duty_date = d2.duty_date
                        AND d1.id < d2.id;

ALTER TABLE duty
    MODIFY duty_date DATE NOT NULL,
    ADD COLUMN team_id BIGINT NULL,
    ADD INDEX idx_duty_team (team_id),
    ADD CONSTRAINT uk_duty_member_date UNIQUE (member_id, duty_date);

UPDATE duty d
    JOIN member m ON m.id = d.member_id
SET d.team_id = m.team_id;
