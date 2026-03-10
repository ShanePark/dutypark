SET @naver_column_exists = (
    SELECT COUNT(*)
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'member'
      AND column_name = 'oauth_naver_id'
);

SET @naver_column_sql = IF(
    @naver_column_exists = 0,
    'ALTER TABLE member ADD COLUMN oauth_naver_id VARCHAR(255) NULL',
    'SELECT 1'
);

PREPARE add_naver_column_stmt FROM @naver_column_sql;
EXECUTE add_naver_column_stmt;
DEALLOCATE PREPARE add_naver_column_stmt;

UPDATE policy_version
SET content = REPLACE(
    REPLACE(
        REPLACE(
            content,
            '| 소셜 로그인(카카오) | 이름, 카카오 계정 고유 식별자 | 필수 |',
            '| 소셜 로그인(카카오/네이버) | 이름, 카카오 또는 네이버 계정 고유 식별자 | 필수 |'
        ),
        '- 카카오 소셜 로그인 시 이용자가 이름 직접 입력
- 카카오 OAuth 연동 시 카카오 계정 식별자 자동 수집',
        '- 카카오 또는 네이버 소셜 로그인 시 이용자가 이름 직접 입력
- 카카오 또는 네이버 OAuth 연동 시 계정 식별자 자동 수집'
    ),
    '| 카카오 | 인증 코드 | 소셜 로그인 처리 | 인증 완료 시 즉시 파기 |',
    '| 카카오 또는 네이버 | 인증 코드 | 소셜 로그인 처리 | 인증 완료 시 즉시 파기 |'
)
WHERE policy_type = 'PRIVACY'
  AND version = '2025-01-15';
