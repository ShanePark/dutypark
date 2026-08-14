# 01. Sign in with Apple

> 상태: 앱·서버 구현과 development 서명 검증 완료 / 운영 비밀, 배포 서명, 실제 계정·TestFlight E2E 대기
> 우선순위: P0
> 최종 확인일: 2026-08-14

[출시 준비 목록으로 돌아가기](../README.md)

## 남은 체크리스트

### 운영 환경과 배포 서명

- [ ] 운영 secret manager에 `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CREDENTIAL_ENCRYPTION_KEY`를 주입한다.
- [ ] 운영 서버가 Apple JWKS 조회, authorization code 교환, refresh token revoke를 수행할 수 있는지 확인한다.
- [ ] 운영 로그, 배포 설정, 컨테이너 이미지와 앱 번들에 private key, token, code, nonce 원문이 없는지 검사한다.
- [ ] App Store distribution 서명 Archive에서 application identifier, provisioning profile과 Sign in with Apple entitlement를 확인한다.
- [ ] Xcode Organizer의 Validate App을 통과한다.

### 실제 계정·TestFlight E2E

- [ ] 실제 Apple 계정으로 신규 가입하고 Dutypark 이름과 필수 정책 동의를 완료한다.
- [ ] 같은 Apple 계정의 재로그인과 로그인 sheet 취소를 확인한다.
- [ ] 기존 이메일·Kakao·Naver 계정에 Apple을 연결한다.
- [ ] 다른 Dutypark 계정에 이미 연결된 Apple `sub` 충돌을 확인한다.
- [ ] 마지막 인증 수단인 Apple의 연결 해제가 차단되는지 확인한다.
- [ ] 다른 인증 수단이 있는 계정에서 Apple revoke 후 연결 해제를 완료한다.
- [ ] Apple-only 계정 삭제를 재인증하고 revoke와 durable 삭제까지 확인한다.
- [ ] 다른 Apple 계정으로 삭제 재인증할 때 mismatch 오류가 나타나는지 확인한다.
- [ ] provider 취소·장애·revoke 실패와 durable worker 재시도를 확인한다.
- [ ] development 실기기와 내부 TestFlight에서 각각 서명·capability·운영 API 흐름을 확인한다.

### 심사 자료

- [ ] App Review Notes에 Apple 신규 가입, 계정 연결·해제와 계정 삭제 재인증의 정확한 경로를 적는다.
- [ ] Apple 이름·이메일 scope를 요청하지 않으며 Dutypark 가입 화면에서 이름과 동의를 직접 받는다고 설명한다.

## 완료 조건

- 운영 비밀이 안전하게 주입된 서버에서 실제 Apple 계정의 가입·로그인·연결·해제·탈퇴가 동작한다.
- App Store distribution 서명 Archive의 Bundle ID, Team, provisioning profile과 Apple entitlement가 일치한다.
- 취소, 충돌, 계정 불일치, provider 장애와 revoke 재시도가 실기기·TestFlight에서 예상한 오류와 복구 흐름을 보인다.
- 심사자가 Review Notes만으로 Apple 관련 흐름을 재현할 수 있다.

## 변하지 않는 정책과 계약

- Apple 로그인 진입점은 iOS 앱에만 제공한다. 웹 Services ID, Website URL, Return URL과 Apple 웹 OAuth flow는 만들지 않는다.
- 웹은 iOS에서 연결된 Apple 상태 표시, revoke-first 연결 해제와 Apple-only 계정의 iOS 탈퇴 안내만 제공한다.
- Team ID는 `2V47G42CDS`, Explicit App ID와 native client ID는 `io.github.shanepark.dutypark`다.
- Apple 이름·이메일 scope를 요청하지 않는다. 검증된 Apple `sub`만 공급자 내부 식별자로 저장하고 이메일이나 이름으로 계정을 자동 병합하지 않는다.
- 신규 Apple 사용자는 기존 Dutypark 가입 화면에서 이름과 필수 약관·개인정보 동의를 직접 완료한다.
- `LOGIN`, `LINK`, `DELETE_ACCOUNT` 목적은 서로 바뀌어 소비될 수 없다.
- 서버는 `alg`, `kid`, JWKS 서명, `iss`, audience, `exp`, `iat`, SHA-256 nonce와 token replay를 검증한다.
- authorization code 교환 결과의 `sub`는 최초 identity token의 `sub`와 같아야 한다.
- Apple refresh token은 AES-256-GCM으로 암호화해 저장하며 기기에는 Apple credential을 영속화하지 않는다.
- 연결 해제와 회원 탈퇴는 provider revoke 성공 전 로컬 mapping을 삭제하지 않는 revoke-first 규칙을 지킨다.
- 마지막 소셜 인증 수단의 연결 해제, 보조 계정과 impersonation 제한은 기존 서버 계약을 따른다.

## 구현 위치

- 서버 API: [`MobileOAuthController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/MobileOAuthController.kt)
- Apple 검증·교환: [`security/oauth/apple`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple)
- credential migration: [`V2.2.31__add_apple_sign_in_credentials.sql`](../../../src/main/resources/db/migration/v2/V2.2.31__add_apple_sign_in_credentials.sql)
- iOS 인증: [`AppleSignInClient.swift`](../../Dutypark/Features/Auth/AppleSignInClient.swift)
- 로그인 화면: [`LoginView.swift`](../../Dutypark/Features/Auth/LoginView.swift)
- 연결·해제: [`SettingsView.swift`](../../Dutypark/Features/Settings/SettingsView.swift)
- 삭제 재인증: [`AccountDeletionView.swift`](../../Dutypark/Features/Settings/AccountDeletionView.swift)
- entitlement: [`Dutypark.entitlements`](../../Dutypark/Dutypark.entitlements)

## 참고

- [App Review Guidelines 4.8 — Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services)
- [Sign in with Apple REST API](https://developer.apple.com/documentation/signinwithapplerestapi)
- [Apple token revoke](https://developer.apple.com/documentation/signinwithapplerestapi/revoke_tokens)
- [TN3194: Handling account deletions and revoking tokens](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
