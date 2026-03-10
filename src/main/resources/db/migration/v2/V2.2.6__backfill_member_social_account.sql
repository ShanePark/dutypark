DELIMITER $$

DROP PROCEDURE IF EXISTS backfill_member_social_account$$

CREATE PROCEDURE backfill_member_social_account()
BEGIN
    IF EXISTS (
        SELECT oauth_kakao_id
        FROM member
        WHERE oauth_kakao_id IS NOT NULL
        GROUP BY oauth_kakao_id
        HAVING COUNT(*) > 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duplicate Kakao social IDs exist in member.oauth_kakao_id';
    END IF;

    IF EXISTS (
        SELECT oauth_naver_id
        FROM member
        WHERE oauth_naver_id IS NOT NULL
        GROUP BY oauth_naver_id
        HAVING COUNT(*) > 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Duplicate Naver social IDs exist in member.oauth_naver_id';
    END IF;

    INSERT INTO member_social_account (member_id, provider, social_id, created_date)
    SELECT id, 'KAKAO', oauth_kakao_id, CURRENT_TIMESTAMP(6)
    FROM member
    WHERE oauth_kakao_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM member_social_account msa
        WHERE msa.member_id = member.id
          AND msa.provider = 'KAKAO'
      );

    INSERT INTO member_social_account (member_id, provider, social_id, created_date)
    SELECT id, 'NAVER', oauth_naver_id, CURRENT_TIMESTAMP(6)
    FROM member
    WHERE oauth_naver_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM member_social_account msa
        WHERE msa.member_id = member.id
          AND msa.provider = 'NAVER'
      );
END$$

CALL backfill_member_social_account()$$

DROP PROCEDURE backfill_member_social_account$$

DELIMITER ;
