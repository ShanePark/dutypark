INSERT INTO policy_version (policy_type, version, content, effective_date, created_at)
SELECT
    'PRIVACY',
    '2026-03-10',
    REPLACE(
        REPLACE(
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
        ),
        '2025-01-15',
        '2026-03-10'
    ),
    '2026-03-10',
    NOW()
FROM policy_version
WHERE policy_type = 'PRIVACY'
  AND version = '2025-01-15'
  AND NOT EXISTS (
      SELECT 1
      FROM policy_version
      WHERE policy_type = 'PRIVACY'
        AND version = '2026-03-10'
  );
