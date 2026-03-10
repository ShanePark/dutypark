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
