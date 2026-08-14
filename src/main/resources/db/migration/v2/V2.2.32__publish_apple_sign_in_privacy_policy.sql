-- Sign in with Apple is native-iOS only. This policy version extends the current
-- full policy without mutating historical policy or consent records.
INSERT INTO policy_version (policy_type, version, content, effective_date, created_at)
SELECT
    'PRIVACY',
    '2026-08-14',
    CONCAT(
        REPLACE(
            REPLACE(
                REPLACE(
                    previous.content,
                    '시행일: 2026-08-13',
                    '시행일: 2026-08-14'
                ),
                '소셜 인증과 관련해 영구 저장하는 계정 정보는 이용자가 Dutypark에 직접 입력한 이름, provider(KAKAO/NAVER), 공급자 고유 식별자입니다. 카카오·네이버 OAuth 과정에서 받은 provider access token은 공급자 고유 식별자를 조회하는 데만 사용하며 Dutypark 데이터베이스에 저장하지 않습니다.',
                '소셜 인증과 관련해 영구 저장하는 계정 정보 중 카카오·네이버는 이용자가 Dutypark에 직접 입력한 이름, provider(KAKAO/NAVER), 공급자 고유 식별자입니다. iOS 전용 Sign in with Apple은 이용자가 Dutypark에 직접 입력한 이름, provider(APPLE), 서명 검증을 마친 Apple sub를 영구 저장합니다. Apple 이름과 이메일은 요청하거나 저장하지 않으며 이메일 일치만으로 기존 계정을 자동 연결하지 않습니다. 카카오·네이버 OAuth 과정에서 받은 provider access token은 공급자 고유 식별자를 조회하는 데만 사용하며 Dutypark 데이터베이스에 저장하지 않습니다. Apple refresh token은 연결 해제와 회원 탈퇴 시 Apple 측 권한을 먼저 철회하기 위해 별도 AES-256-GCM 키로 암호화해 저장합니다.'
            ),
            '

- 공고일: 2026-08-13
- 시행일: 2026-08-14',
            ''
        ),
        '

## 제10조 iOS 전용 Sign in with Apple 처리

1. 서비스는 iOS 앱의 로그인, 계정 연결 및 회원 탈퇴 재인증에만 Sign in with Apple을 사용합니다. 웹용 Apple 로그인이나 Apple Services ID 로그인은 제공하지 않습니다.
2. iOS 앱은 Apple에 이름과 이메일 scope를 요청하지 않습니다. Apple 이름과 이메일을 Dutypark 서버로 전송하거나 저장하지 않으며, 이메일이 같다는 이유만으로 기존 Dutypark 계정과 자동 병합하지 않습니다.
3. 계정 식별을 위해 provider(APPLE)와 Apple이 발급하고 서버가 서명·issuer·audience·만료·발급 시각·nonce를 검증한 sub를 영구 저장합니다. sub는 Apple 계정과 Dutypark 계정의 연결을 유지하고 로그인 대상을 찾는 데 사용합니다.
4. 인증 요청마다 iOS 앱은 무작위 raw nonce와 state를 생성합니다. SHA-256 처리한 nonce와 state는 Apple 인증 요청에 사용하고, 반환된 state는 iOS 앱에서 요청 값과 일치하는지 확인한 뒤 폐기합니다. 서버는 identity token, authorization code와 raw nonce를 받아 identity token의 nonce claim을 검증합니다. identity token, authorization code, raw nonce와 state는 인증 요청 중에만 일시 처리하고 원문을 운영 로그나 데이터베이스에 저장하지 않습니다.
5. identity token 재사용 방지를 위해 서버는 token 원문 전체의 SHA-256 해시와 token 만료 시각만 저장합니다. 이 해시는 token 만료 후 1일의 정리 유예 기간을 거쳐 매일 삭제합니다. authorization code는 Apple token endpoint에서 일회용으로 검증합니다.
6. 서버는 Apple token endpoint(/auth/token)에 authorization code, iOS App ID인 client_id와 서버가 Apple Team ID·Key ID·EC private key로 생성한 짧은 수명의 ES256 client_secret을 전송합니다. Apple에서 받은 identity token은 같은 sub인지 다시 검증하고, refresh token은 아래 철회 목적에 한해 사용합니다.
7. Apple refresh token은 일반 세션 refresh_token이나 JWT secret과 분리된 32-byte 전용 키로 AES-256-GCM 암호화해 저장합니다. 계정에 연결된 credential은 Apple 계정 연결을 유지하는 동안 보유합니다. 가입을 완료하지 않아 어느 회원에게도 연결되지 않은 credential은 1일이 지난 orphan으로 판단하고 매일 정리 작업에서 Apple 권한을 철회한 뒤 삭제합니다.
8. Apple 계정 연결 해제 시 서버는 Apple revoke endpoint(/auth/revoke)에 복호화한 refresh token, client_id와 client_secret을 전송해 Apple 측 권한을 먼저 철회합니다. 성공 응답을 받은 뒤 provider(APPLE) 연결과 암호화 credential을 삭제합니다. 철회가 실패하면 로컬 연결과 credential을 보존해 다시 시도할 수 있게 합니다.
9. 회원 탈퇴 시에도 삭제 작업은 Apple revoke endpoint에 같은 정보를 전송해 Apple 측 권한을 먼저 철회하고, 성공한 뒤 Dutypark 계정 데이터와 provider(APPLE) 연결 및 암호화 credential을 삭제합니다. 카카오·네이버에는 기존과 같이 저장된 철회 credential이 없어 이 절차를 적용하지 않습니다.
10. Apple에 공유되는 정보는 token 검증 시 authorization code·client_id·client_secret, 권한 철회 시 refresh token·client_id·client_secret입니다. 목적은 iOS 전용 Apple 로그인 자격 증명 검증과 계정 연결 해제·회원 탈퇴 시 Apple 권한 철회이며, Dutypark는 Apple 이름이나 이메일을 요청·공유·저장하지 않습니다.

- 공고일: 2026-08-13
- 시행일: 2026-08-14'
    ),
    '2026-08-14',
    NOW()
FROM policy_version previous
WHERE previous.policy_type = 'PRIVACY'
  AND previous.version = '2026-08-13'
  AND NOT EXISTS (
      SELECT 1
      FROM policy_version current_version
      WHERE current_version.policy_type = 'PRIVACY'
        AND current_version.version = '2026-08-14'
  );
