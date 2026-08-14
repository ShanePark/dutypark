# 01. Sign in with Apple

> 기준일·최종 확인일: 2026-08-14
> 우선순위: P0
> 상태: 저장소 구현·Apple App ID/key·development 서명 검증 완료 / 운영 비밀·실계정 E2E 대기

[전체 출시 준비 체크리스트로 돌아가기](../README.md)

## 목표와 적용 범위

카카오·네이버 같은 제3자 로그인을 주 계정 인증에 사용하는 iOS 앱에서 Apple App Review Guideline 4.8을 충족하고,
Apple 사용자가 신규 가입, 기존 로그인, 계정 연결·해제와 회원 탈퇴 재인증을 안전하게 수행하게 한다.

- **Apple 로그인 진입점은 iOS 앱에만 제공한다.** 웹에는 Apple 로그인 버튼, Services ID, Return URL 또는 Apple 웹 OAuth flow를 만들지 않는다.
- 웹은 iOS에서 연결된 Apple 상태 표시, 서버의 revoke-first 연결 해제, Apple-only 계정 삭제 시 iOS 앱 이용 안내만 제공한다.
- Apple 이름·이메일 scope를 요청하지 않는다. 검증된 Apple `sub`만 계정 연결 키로 사용하며 가입 이름과 동의는 기존 Dutypark 가입 화면에서 직접 받는다.
- Apple Developer Program 개인 멤버십은 2026-08-14 승인됐고 Team ID는 `2V47G42CDS`다. Explicit App ID와 Xcode Bundle ID는 `io.github.shanepark.dutypark`로 확정했다.

## 현재 구현 위치

- 백엔드 native exchange API: [`MobileOAuthController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/MobileOAuthController.kt)
- Apple 검증·교환·로그인 서비스: [`security/oauth/apple`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple)
- Apple credential·replay migration: [`V2.2.31__add_apple_sign_in_credentials.sql`](../../../src/main/resources/db/migration/v2/V2.2.31__add_apple_sign_in_credentials.sql)
- iOS Apple 인증 클라이언트: [`AppleSignInClient.swift`](../../Dutypark/Features/Auth/AppleSignInClient.swift)
- iOS 로그인 화면: [`LoginView.swift`](../../Dutypark/Features/Auth/LoginView.swift)
- iOS 연결·해제 화면: [`SettingsView.swift`](../../Dutypark/Features/Settings/SettingsView.swift)
- iOS 삭제 재인증: [`AccountDeletionView.swift`](../../Dutypark/Features/Settings/AccountDeletionView.swift)
- entitlement: [`Dutypark.entitlements`](../../Dutypark/Dutypark.entitlements)

## 확정된 정책

- [x] Apple 로그인·가입·연결·삭제 재인증 진입점은 iOS 전용으로 제공한다.
- [x] 웹 Services ID와 Apple 웹 OAuth flow는 이번 범위에서 만들지 않는다.
- [x] Apple의 검증된 `sub`를 공급자 내부의 불변 식별자로 저장하고 이메일을 계정 키로 사용하지 않는다.
- [x] Apple 이름·이메일 scope를 요청하거나 이름·이메일을 Apple 응답에서 수집하지 않는다.
- [x] 동일 이메일 추정이나 이름을 이용한 자동 병합을 하지 않는다.
- [x] 신규 Apple 사용자는 기존 SSO 가입 화면에서 이름과 필수 약관·개인정보 동의를 직접 완료한다.
- [x] 로그인 사용자는 iOS 설정에서 Apple 계정을 연결하고, Apple 인증 수단으로 탈퇴 재인증할 수 있다.
- [x] 마지막 소셜 인증 수단은 연결 해제를 차단한다.
- [x] Apple 연결 해제는 provider revoke가 성공한 뒤 로컬 mapping을 삭제한다.
- [x] 회원 탈퇴는 암호화해 보관한 refresh token을 durable worker에서 revoke한 뒤 로컬 데이터를 정리하며, 실패는 job 재시도 대상으로 남긴다.
- [x] 보조 계정과 impersonation의 기존 연결·해제·탈퇴 제한을 그대로 적용한다.

## 백엔드 구현

- [x] `POST /api/auth/mobile/oauth/apple/exchange`에 `identityToken`, `authorizationCode`, raw `nonce`, `purpose`를 받는다.
- [x] `LOGIN`, `LINK`, `DELETE_ACCOUNT` 목적을 지원하고 기존 모바일 OAuth 응답과 HttpOnly access/refresh cookie 계약을 유지한다.
- [x] JWT header의 `alg=RS256`, `kid`와 Apple JWKS의 RSA signing key를 검증한다.
- [x] `iss=https://appleid.apple.com`, native client ID audience, `exp`, `iat`, SHA-256 nonce를 검증한다.
- [x] JWKS를 6시간 캐시하고 provider 장애와 잘못된 credential을 기계 판독 가능한 서로 다른 오류 코드로 반환한다.
- [x] identity token hash를 DB에 일회성으로 소비해 replay를 차단하고 만료 레코드를 정리한다.
- [x] authorization code를 Apple token endpoint에서 교환하고, 교환 결과 token의 `sub`가 최초 identity token과 같은지 확인한다.
- [x] 서버용 client secret을 Team ID·Key ID·`.p8`로 ES256 서명한다.
- [x] Apple refresh token을 AES-256-GCM으로 암호화해 저장하고 token·code·nonce 원문을 로그에 남기지 않는다.
- [x] Apple `sub`와 provider 조합의 유일성을 DB·서비스 계층에서 강제하고, 기존 계정을 이메일로 자동 병합하지 않는다.
- [x] Apple 연결 해제와 회원 탈퇴에서 revoke-first 규칙을 적용한다. provider 실패 시 로컬 mapping을 먼저 지우지 않는다.
- [x] Apple 전용 환경 변수가 비어 있어도 서버는 기동하며, Apple 요청만 `auth.apple.configurationUnavailable`로 거부한다.
- [x] DB migration 버전은 `V2.2.31`이다.
- [x] `V2.2.32`로 최신 서비스 `PRIVACY 2026-08-14`를 게시해 Apple `sub`, 일시 token·code·nonce·state, replay hash·만료, 암호화 refresh credential과 revoke-first 처리를 공개한다.
- [x] 정책 migration은 기존 consent를 변경하거나 기존 회원 재동의 gate를 만들지 않고, 신규 SSO 가입은 서버의 current privacy version 동의를 요구한다.

## iOS 구현

- [x] `AuthenticationServices`의 표준 `SignInWithAppleButton`을 로그인 화면에 제공한다.
- [x] 버튼은 라이트·다크 모드에 맞춘 표준 스타일, 52pt 높이와 접근성 식별자를 사용한다.
- [x] 매 요청마다 `SecRandomCopyBytes`로 32바이트 nonce와 state를 생성하고, Apple에는 SHA-256 nonce를 보내며 서버에는 raw nonce를 전달한다.
- [x] identity token, authorization code와 state 부재·불일치를 거부한다.
- [x] 이름·이메일 scope를 요청하지 않는다.
- [x] 신규 가입과 기존 로그인을 구분해 기존 `SsoSignupView` 또는 인증 세션으로 이동한다.
- [x] iOS 설정에서 Apple 연결·revoke-first 해제와 계정 삭제 재인증을 제공한다.
- [x] 취소, 설정 누락, 잘못된 credential, 공급자 장애, 계정 불일치를 한국어·영어로 구분한다.
- [x] Apple user identifier, identity token, authorization code, nonce를 기기에 영속화하거나 콘솔에 기록하지 않는다.
- [x] `com.apple.developer.applesignin = Default` entitlement를 소스·Debug/Release Simulator 처리 산출물과 development 서명된 generic iOS Release 앱에서 확인했다.

## 웹 범위

- [x] 웹에는 Apple 로그인·가입·연결·재인증 버튼을 제공하지 않는다.
- [x] Services ID, Website URL, Return URL과 Apple 웹 callback/state flow는 필요하지 않으며 만들지 않는다.
- [x] iOS에서 연결된 Apple 상태를 회원정보에 표시한다.
- [x] 웹에서도 Apple 연결 해제를 요청할 수 있으며 서버가 Apple revoke 성공 후 로컬 mapping을 삭제한다.
- [x] Apple-only 계정은 웹에서 Apple 재인증을 시작하지 않고 iOS 앱에서 삭제를 완료하도록 안내한다.
- [x] 비밀번호나 Kakao·Naver 등 다른 재인증 수단이 있으면 웹 계정 삭제는 해당 수단을 계속 사용할 수 있다.

## 자동 검증 기록

### 백엔드

- [x] Apple 전용 7개 test class의 신규 검증 19/19가 통과했다. provider HTTP client의 JWKS·token exchange·revoke와 오류 매핑을 포함한다.
- [x] Apple 적용에 영향받는 기존 mobile OAuth, member DTO, 연결·해제와 account deletion 회귀 묶음 25/25 및 60/60이 통과했다.
- [!] 전체 백엔드 suite는 785개를 포함한 실행에서 기존 `ScheduleSearch` context 5개가 JVM OOM을 일으켜 clean pass로 기록하지 않는다. 해당 class 단독 실행은 통과했으며 Apple targeted 결과와 구분한다.

### iOS

- [x] `AppleSignInClientTests`, mobile OAuth·settings targeted test와 Apple 로그인 UI presence 검증이 통과했다.
- [x] iPhone 16 Pro Simulator 전체 suite 278/278을 1회 통과했다. 실패·건너뜀은 0개였다.
- [x] Release Simulator clean build가 성공했다.
- [x] Simulator의 처리된 `.xcent`에서 `com.apple.developer.applesignin = Default`를 확인했다.

### 웹 회귀

- [x] Apple 로그인 진입점 없이 연결 상태·revoke-first unlink·삭제 안내만 제공하는 계약을 검증했다.
- [x] Vitest 34 files/162 tests, type-check, production build와 release-notes check가 통과했다.

## Apple Developer 및 운영 환경 항목

- [x] Apple Developer Program 개인 멤버십 승인을 완료했다(2026-08-14).
- [x] `io.github.shanepark.dutypark` Explicit App ID를 등록하고 최종 Bundle ID로 확정했다.
- [x] Explicit App ID에서 Sign in with Apple, Push Notifications, Associated Domains capability를 활성화했다.
- [x] Xcode target의 Development Team `2V47G42CDS`, Bundle ID, Apple native client ID와 development provisioning profile을 일치시켰다.
- [x] Sign in with Apple server key를 만들고 Key ID `4D85ZS4KM2`를 확인했다. 개인 키 원문·경로는 문서나 Git에 남기지 않는다.
- [-] 별도의 32바이트 credential 암호화 키를 생성해 로컬 로그인 키체인에 보관했다. 운영 환경 실제 주입은 남아 있다.
- [ ] `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CREDENTIAL_ENCRYPTION_KEY`를 운영에 주입한다.
- [x] `docker-compose.yml`이 위 Apple 환경 변수를 서버 컨테이너에 전달하도록 연결했다.
- [x] 웹 Services ID, Website URL과 Return URL은 만들지 않는다.
- [x] development 서명된 generic iOS Release 앱에서 application identifier, provisioning profile, Sign in with Apple `Default`, Associated Domains entitlement를 확인했다.
- [ ] App Store distribution 서명 Archive에서도 entitlement와 provisioning profile을 확인하고 Validate App을 통과한다.
- [ ] App Review Notes에 iOS Apple 로그인 신규 가입·연결·탈퇴 재인증 경로를 설명한다.

비밀값은 Git, 문서, 이슈, 로그, 스크린샷 또는 앱 번들에 남기지 않는다.

## 실제 기기·TestFlight 검증 시나리오

- [ ] 실제 Apple 계정으로 신규 가입하고 Dutypark 이름·필수 동의를 완료한다.
- [ ] 같은 Apple 계정으로 재로그인한다.
- [ ] 사용자가 로그인 sheet를 취소했을 때 현재 화면과 상태가 유지되는지 확인한다.
- [ ] 기존 이메일·Kakao·Naver 계정에 Apple을 연결한다.
- [ ] 이미 다른 Dutypark 계정에 연결된 Apple `sub` 충돌을 확인한다.
- [ ] 마지막 인증 수단인 Apple 연결 해제가 차단되는지 확인한다.
- [ ] 다른 인증 수단이 있는 계정에서 Apple revoke 성공 후 연결 해제가 완료되는지 확인한다.
- [ ] Apple 전용 계정 삭제를 iOS에서 재인증하고 revoke·durable 삭제까지 확인한다.
- [ ] 다른 Apple 계정으로 삭제 재인증할 때 mismatch 오류가 나타나는지 확인한다.
- [ ] Apple provider 취소·장애·revoke 실패와 worker 재시도를 확인한다.
- [ ] iPhone 실기기와 내부 TestFlight에서 서명·capability·운영 API 흐름을 각각 확인한다.

## 완료 조건

- [x] 저장소에서 native Apple 로그인·가입·연결·해제·삭제 재인증과 revoke 경로가 구현되고 targeted 자동 검증을 통과했다.
- [x] Apple `sub` 유일성, token 필수 claim·nonce·replay와 no-auto-merge 정책이 서버에서 강제된다.
- [x] 웹에 Apple OAuth flow를 추가하지 않는 제품 범위가 구현과 문서에 일치한다.
- [-] 실제 App ID, server key와 development provisioning 설정은 완료했다. 운영 비밀 실제 주입과 App Store distribution 서명은 남아 있다.
- [ ] 실기기·TestFlight에서 신규 가입, 재로그인, 연결, 충돌, 취소, 연결 해제와 탈퇴 revoke를 통과한다.
- [ ] App Store distribution 서명 Archive에서 최종 entitlement를 검증한다.
- [ ] 로그·배포 환경·Archive에 key, token, code, nonce 원문 등 비밀값이 없는지 최종 확인한다.

## 출시 후 보강

- [ ] Apple server-to-server notification과 credential 상태 변경 처리를 별도 hardening 작업으로 평가한다. 현재 로그인·연결·탈퇴 출시 경로의 완료로 오인하지 않는다.

## 공식 참고 링크

- [App Review Guidelines 4.8 — Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services)
- [Sign in with Apple 개요](https://developer.apple.com/sign-in-with-apple/)
- [Sign in with Apple REST API](https://developer.apple.com/documentation/signinwithapplerestapi)
- [Apple로 로그인하여 사용자 인증](https://developer.apple.com/documentation/authenticationservices/authenticating-users-with-sign-in-with-apple)
- [Apple token revoke](https://developer.apple.com/documentation/signinwithapplerestapi/revoke_tokens)
- [TN3194: Sign in with Apple account deletion](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
