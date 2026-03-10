ALTER TABLE member
    DROP INDEX uk_member_oauth_kakao_id,
    DROP INDEX uk_member_oauth_naver_id,
    DROP COLUMN oauth_kakao_id,
    DROP COLUMN oauth_naver_id;
