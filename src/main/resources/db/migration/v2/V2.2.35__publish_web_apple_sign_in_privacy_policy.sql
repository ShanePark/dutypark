-- Sign in with Apple now supports login and sign-up on both iOS and web.
-- This policy version preserves the historical native-only policy and its consents.
INSERT INTO policy_version (policy_type, version, content, effective_date, created_at)
SELECT
    'PRIVACY',
    '2026-08-15',
    CONCAT(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            LEFT(
                                previous.content,
                                LOCATE(
                                    '

## 제10조 iOS 전용 Sign in with Apple 처리',
                                    previous.content
                                ) - 1
                            ),
                            '시행일: 2026-08-14',
                            '시행일: 2026-08-15'
                        ),
                        '| 카카오·네이버 회원가입 및 계정 연결 | 이용자가 Dutypark에 직접 입력한 이름, provider(KAKAO/NAVER), 공급자 고유 식별자 | OAuth 인증 결과에서 고유 식별자만 확인합니다. 공급자 프로필 이름이나 이메일은 요청하거나 저장하지 않습니다. |',
                        '| 카카오·네이버 회원가입 및 계정 연결 | 이용자가 Dutypark에 직접 입력한 이름, provider(KAKAO/NAVER), 공급자 고유 식별자 | OAuth 인증 결과에서 고유 식별자만 확인합니다. 공급자 프로필 이름이나 이메일은 요청하거나 저장하지 않습니다. |
| Apple 회원가입·로그인·계정 연결 및 iOS 탈퇴 재인증 | 이용자가 Dutypark에 직접 입력한 이름, provider(APPLE), Apple sub, 암호화한 refresh token, 발급 client_id | iOS 앱 또는 웹의 Sign in with Apple 인증 결과를 서버가 검증합니다. Apple 이름이나 이메일은 요청하거나 저장하지 않습니다. |'
                    ),
                    '| 모바일 소셜 OAuth | provider, 인증 목적, callback, authorization code, state와 그 해시, PKCE code challenge·verifier 검증 정보, 일회용 교환 코드와 만료·사용 시각 | iOS에서 로그인·계정 연결·재인증을 진행하는 동안 일시 처리됩니다. |',
                    '| 소셜 OAuth | provider, 인증 목적, callback, authorization code, identity token, raw nonce, state와 그 해시, PKCE code challenge·verifier 검증 정보, 일회용 교환 코드와 만료·사용 시각 | iOS 앱과 웹에서 로그인·가입·계정 연결을, iOS 앱에서 탈퇴 재인증을 진행하는 동안 각 인증 흐름에 필요한 항목만 일시 처리됩니다. |'
                ),
                '소셜 인증과 관련해 영구 저장하는 계정 정보 중 카카오·네이버는 이용자가 Dutypark에 직접 입력한 이름, provider(KAKAO/NAVER), 공급자 고유 식별자입니다. iOS 전용 Sign in with Apple은 이용자가 Dutypark에 직접 입력한 이름, provider(APPLE), 서명 검증을 마친 Apple sub를 영구 저장합니다. Apple 이름과 이메일은 요청하거나 저장하지 않으며 이메일 일치만으로 기존 계정을 자동 연결하지 않습니다. 카카오·네이버 OAuth 과정에서 받은 provider access token은 공급자 고유 식별자를 조회하는 데만 사용하며 Dutypark 데이터베이스에 저장하지 않습니다. Apple refresh token은 연결 해제와 회원 탈퇴 시 Apple 측 권한을 먼저 철회하기 위해 별도 AES-256-GCM 키로 암호화해 저장합니다.',
                '소셜 인증과 관련해 영구 저장하는 계정 정보 중 카카오·네이버는 이용자가 Dutypark에 직접 입력한 이름, provider(KAKAO/NAVER), 공급자 고유 식별자입니다. Sign in with Apple은 iOS 앱과 웹에서 이용자가 Dutypark에 직접 입력한 이름, provider(APPLE), 서명 검증을 마친 Apple sub를 영구 저장합니다. Apple 이름과 이메일은 요청하거나 저장하지 않으며 이메일 일치만으로 기존 계정을 자동 연결하지 않습니다. 카카오·네이버 OAuth 과정에서 받은 provider access token은 공급자 고유 식별자를 조회하는 데만 사용하며 Dutypark 데이터베이스에 저장하지 않습니다. Apple refresh token과 이를 발급받은 client_id는 연결 해제와 회원 탈퇴 시 Apple 측 권한을 먼저 철회하기 위해 저장하며, refresh token은 별도 AES-256-GCM 키로 암호화합니다.'
            ),
            '| Naver | 공급자로부터 authorization code와 고유 식별자를 수신합니다. Dutypark는 표준 OAuth token 교환에 필요한 code·state·client 정보를 Naver 인증 서버에 전송하고, 발급된 access token으로 고유 식별자만 조회합니다. | 네이버 로그인, 계정 연결 및 재인증 |',
            '| Naver | 공급자로부터 authorization code와 고유 식별자를 수신합니다. Dutypark는 표준 OAuth token 교환에 필요한 code·state·client 정보를 Naver 인증 서버에 전송하고, 발급된 access token으로 고유 식별자만 조회합니다. | 네이버 로그인, 계정 연결 및 재인증 |
| Apple | Apple로부터 identity token, authorization code와 refresh token을 수신합니다. Dutypark는 token 교환과 권한 철회에 필요한 credential과 client 정보를 Apple 인증 서버에 전송합니다. | iOS 앱·웹 Apple 로그인·가입·계정 연결, iOS 탈퇴 재인증 및 Apple 권한 철회 |'
        ),
        '

## 제10조 iOS 앱·웹 Sign in with Apple 처리

1. 서비스는 iOS 앱과 웹에서 로그인, 신규 가입 및 기존 계정 연결에 Sign in with Apple을 사용합니다. Apple 재인증이 필요한 회원 탈퇴는 iOS 앱에서만 제공합니다.
2. iOS 앱과 웹은 Apple에 이름과 이메일 scope를 요청하지 않습니다. Apple 이름과 이메일을 Dutypark 서버로 전송하거나 저장하지 않으며, 이메일이 같다는 이유만으로 기존 Dutypark 계정과 자동 병합하지 않습니다.
3. 계정 식별을 위해 provider(APPLE)와 Apple이 발급하고 서버가 서명·issuer·audience·만료·발급 시각·nonce를 검증한 sub를 영구 저장합니다. sub는 Apple 계정과 Dutypark 계정의 연결을 유지하고 로그인 대상을 찾는 데 사용합니다.
4. 인증 요청마다 iOS 앱과 웹은 무작위 raw nonce와 state를 생성하고 Apple 인증 요청에는 SHA-256 처리한 nonce와 비교용 state를 사용합니다. 웹은 Apple Services ID와 등록된 Return URL을 사용하는 Apple 로그인 팝업에서, iOS 앱은 Apple 인증 응답에서 반환된 state 원문을 요청 값과 대조한 뒤 폐기합니다. 서버는 identity token, authorization code와 raw nonce를 받고 state는 전송받지 않으며, identity token의 nonce claim을 검증합니다. identity token, authorization code, raw nonce와 state는 인증 요청 중에만 일시 처리하고 원문을 운영 로그나 데이터베이스에 저장하지 않습니다.
5. identity token 재사용 방지를 위해 서버는 token 원문 전체의 SHA-256 해시와 token 만료 시각만 저장합니다. 이 해시는 token 만료 후 1일의 정리 유예 기간을 거쳐 매일 삭제합니다. authorization code는 Apple token endpoint에서 일회용으로 검증합니다.
6. 서버는 Apple token endpoint(/auth/token)에 authorization code, iOS App ID 또는 웹 Services ID인 client_id와 서버가 Apple Team ID·Key ID·EC private key로 생성한 짧은 수명의 ES256 client_secret을 전송합니다. 웹 인증에는 등록된 redirect_uri도 함께 전송합니다. Apple에서 받은 identity token은 같은 sub인지 다시 검증하고, refresh token은 아래 철회 목적에 한해 사용합니다.
7. Apple refresh token은 일반 세션 refresh_token이나 JWT secret과 분리된 32-byte 전용 키로 AES-256-GCM 암호화하고, refresh token을 발급받은 client_id와 함께 저장합니다. 계정에 연결된 credential은 Apple 계정 연결을 유지하는 동안 보유합니다. 가입을 완료하지 않아 어느 회원에게도 연결되지 않은 credential은 orphan으로 관리합니다. 계정 연결 실패 후 새로 발급된 credential을 즉시 철회하지 못한 경우에도 Apple sub 대신 무작위 내부 재시도 식별자와 함께 독립된 트랜잭션으로 암호화해 저장합니다. 1일이 지난 orphan credential은 매일 정리 작업에서 Apple 권한 철회를 다시 시도하고, 성공한 뒤 삭제합니다.
8. Apple 계정 연결 해제 시 서버는 Apple revoke endpoint(/auth/revoke)에 복호화한 refresh token, 해당 refresh token을 발급한 client_id와 그 client_id로 생성한 client_secret을 전송해 Apple 측 권한을 먼저 철회합니다. 성공 응답을 받은 뒤 provider(APPLE) 연결과 암호화 credential을 삭제합니다. 철회가 실패하면 로컬 연결과 credential을 보존해 다시 시도할 수 있게 합니다.
9. 회원 탈퇴 시에도 삭제 작업은 Apple revoke endpoint에 같은 정보를 전송해 Apple 측 권한을 먼저 철회하고, 성공한 뒤 Dutypark 계정 데이터와 provider(APPLE) 연결 및 암호화 credential을 삭제합니다. 카카오·네이버에는 기존과 같이 저장된 철회 credential이 없어 이 절차를 적용하지 않습니다.
10. Apple에 공유되는 정보는 token 검증 시 authorization code·client_id·client_secret과 웹 인증의 redirect_uri, 권한 철회 시 refresh token·client_id·client_secret입니다. 목적은 iOS 앱·웹 Apple 로그인·계정 연결 자격 증명 검증과 계정 연결 해제·회원 탈퇴 시 Apple 권한 철회이며, Dutypark는 Apple 이름이나 이메일을 요청·공유·저장하지 않습니다.

- 공고일: 2026-08-14
- 시행일: 2026-08-15'
    ),
    '2026-08-15',
    NOW()
FROM policy_version previous
WHERE previous.policy_type = 'PRIVACY'
  AND previous.version = '2026-08-14'
  AND NOT EXISTS (
      SELECT 1
      FROM policy_version current_version
      WHERE current_version.policy_type = 'PRIVACY'
        AND current_version.version = '2026-08-15'
  );
