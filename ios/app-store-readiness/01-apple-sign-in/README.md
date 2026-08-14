# 01. Sign in with Apple

> 구현 상태: iOS·서버·웹 로그인/가입/계정 연결 완료
> 출시 검증 상태: Services ID·primary App ID·운영 domain·Return URL 등록과 소스 빌드 설정 완료 / 개인정보 처리방침 시행 후 운영 배포·환경 주입, 배포 서명, 실제 계정·TestFlight·웹 E2E 대기
> 우선순위: P0
> 최종 확인일: 2026-08-14

[출시 준비 목록으로 돌아가기](../README.md)

## 문서 현행화 규칙

- 이 항목과 관련된 구현·설정·검증·배포 임무를 수행한 뒤에는 같은 임무 안에서 이 README와 현재 또는 향후 하위 문서를 즉시 현행화한다.
- 상태, 체크리스트, 최종 확인일, 변하지 않는 정책과 계약, 구현 위치와 검증 근거를 실제 코드·설정·테스트 결과 및 최근 변경 이력과 일치시킨다.
- 아직 운영 환경, 실제 계정, 실기기, TestFlight 또는 배포 서명으로 검증하지 않은 항목은 구현 완료와 구분하고 완료 처리하지 않는다.

## 구현 상태

- [x] iOS에서 Apple 로그인·신규 가입, 기존 계정 연결, revoke-first 연결 해제와 계정 삭제 재인증을 제공한다.
- [x] 서버가 Apple JWKS와 identity token의 서명·claim·nonce·재사용을 검증하고 authorization code를 교환한다.
- [x] Apple `sub`를 기존 Dutypark 계정 mapping에 사용하고 refresh token을 암호화해 revoke-first 흐름에 사용한다.
- [x] 웹에서 Apple 연결 상태를 표시하고 revoke-first 연결 해제를 제공한다.
- [x] 웹에서 Apple 로그인·신규 가입 진입점을 제공한다.
- [x] 웹의 기존 계정에서 Apple `LINK` 인증을 시작하고, 인증된 Apple `sub`를 현재 Dutypark 회원에게 연결한다.
- [x] 웹이 암호학적 무작위 `state`와 nonce를 메모리에만 유지하고, Apple JS 팝업 응답의 `state`를 교환 전에 검증하며, 서버는 nonce·token·재사용을 검증한다.
- [x] 웹 Apple 로그인·연결 흐름의 정상·취소·위조 state·nonce 불일치·token 검증 실패·중복 연결·revoke 실패를 자동 테스트로 고정한다.
- [x] iOS Apple 흐름의 credential 누락·state 불일치·취소·provider 장애, `LINK`·`DELETE_ACCOUNT`의 401 후 동일 credential 1회 재시도와 `LOGIN`의 비재시도 계약을 회귀 테스트로 고정한다.
- [x] 서버가 같은 Apple `sub`의 native/web refresh credential을 client ID별로 보관하고, 연결 해제·탈퇴 시 모두 각 발급 client ID로 revoke한다.
- [x] Apple `LINK` 실패로 남은 refresh token은 즉시 보상 revoke하고, revoke도 실패하면 암호화된 재시도 레코드로 남겨 일일 정리 작업에서 다시 revoke한다.
- [x] 서버가 기존 Apple 로그인 회원과 연결 대상 회원을 행 잠금으로 확인하고, 활성 회원이 아닌 로그인·연결 요청을 거부한다.
- [x] 웹 Apple exchange는 일회용 credential POST이므로 401 때 세션 refresh나 요청 replay를 하지 않는다.

## 남은 출시 체크리스트

### Apple Developer 웹 설정

- [x] 운영 웹 로그인용 Services ID를 생성했다.
- [x] Services ID identifier를 `io.github.shanepark.dutypark.web`으로 확정했다.
- [x] Services ID의 Website URL에 운영 도메인 `dutypark.o-r.kr`을 등록했다.
- [x] Services ID의 Return URL에 `https://dutypark.o-r.kr/auth/apple/callback`을 scheme·host·path까지 등록했다.
- [x] Services ID를 primary App ID `2V47G42CDS.io.github.shanepark.dutypark`와 그룹으로 연결했다.
- [x] 기존 iOS 서버용 Sign in with Apple key `Dutypark Sign in with Apple`을 같은 primary App ID에 연결된 웹 Services ID에서도 재사용한다. 별도 웹 전용 key는 만들지 않는다.
- 참고: Apple 이름·이메일 scope를 요청하지 않으므로 Sign in with Apple용 이메일 발신 도메인·주소 등록은 이 흐름의 필수 설정이 아니다.
- [x] 소스 빌드 설정에서 로컬 `VITE_APPLE_CLIENT_ID`·`VITE_APPLE_REDIRECT_URI`는 비워 버튼을 비활성화하고, `frontend/.env.production`에는 Services ID `io.github.shanepark.dutypark.web`과 `https://dutypark.o-r.kr/auth/apple/callback`을 반영했다.
- [ ] 같은 Apple 계정이 앱과 웹에서 동일한 Apple `sub`로 식별되는지 실제 응답으로 확인한다. 그룹 연결 전에 생성된 계정의 transfer 영향이 있으면 별도 이행 계획을 확정한다.

### 개인정보 처리방침 시행과 기능 활성화

- [x] 웹 Apple 로그인·가입·계정 연결과 관련 처리 내용을 담은 개인정보 처리방침 `2026-08-15` migration을 추가했다.
- [ ] `2026-08-15 00:00 KST` 이후 새 개인정보 처리방침이 current 정책으로 적용·제공되는 것을 확인한 뒤 웹 Apple 로그인·계정 연결 코드를 운영에 배포하고 기능을 활성화한다. 그 전에는 운영에서 해당 기능을 노출하거나 사용할 수 있게 하지 않는다.

### 운영 환경과 배포 서명

- [ ] 운영 배포 설정에 `APPLE_CLIENT_ID`, `APPLE_WEB_CLIENT_ID`, `APPLE_WEB_REDIRECT_URI`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`, `APPLE_CREDENTIAL_ENCRYPTION_KEY`를 주입하고 private key와 암호화 key는 secret manager에서만 공급한다.
- [ ] 실제 운영 프런트엔드 artifact에 `VITE_APPLE_CLIENT_ID=io.github.shanepark.dutypark.web`과 `VITE_APPLE_REDIRECT_URI=https://dutypark.o-r.kr/auth/apple/callback`이 포함됐는지 확인하고, 운영 서버 환경값·Apple Developer 설정과 일치하는지 검증한다.
- [ ] 운영 서버가 Apple JWKS 조회, authorization code 교환, refresh token revoke를 수행할 수 있는지 확인한다.
- [ ] 운영 로그, 배포 설정, 컨테이너 이미지와 앱 번들에 private key, token, code, nonce 원문이 없는지 검사한다.
- [ ] App Store distribution 서명 Archive에서 application identifier, provisioning profile과 Sign in with Apple entitlement를 확인한다.
- [ ] Xcode Organizer의 Validate App을 통과한다.

### 실제 계정·앱↔웹·TestFlight E2E

- [ ] 실제 Apple 계정으로 신규 가입하고 Dutypark 이름과 필수 정책 동의를 완료한다.
- [ ] 같은 Apple 계정의 재로그인과 로그인 sheet 취소를 확인한다.
- [ ] 앱에서 Apple로 가입한 뒤 웹에서 같은 Apple 계정으로 로그인하면 신규 계정이 생기지 않고 같은 Dutypark 회원으로 로그인되는지 확인한다.
- [ ] 웹에서 Apple로 가입한 뒤 앱에서 같은 Apple 계정으로 로그인해도 같은 Dutypark 회원으로 로그인되는지 확인한다.
- [ ] 기존 이메일·Kakao·Naver 계정에 iOS 앱과 웹에서 각각 Apple을 연결하고, 양쪽에서 같은 연결 상태와 회원을 조회하는지 확인한다.
- [ ] 다른 Dutypark 계정에 이미 연결된 Apple `sub` 충돌을 확인한다.
- [ ] 마지막 인증 수단인 Apple의 연결 해제가 차단되는지 확인한다.
- [ ] 다른 인증 수단이 있는 계정에서 Apple revoke 후 연결 해제를 완료한다.
- [ ] Apple-only 계정 삭제를 재인증하고 revoke와 durable 삭제까지 확인한다.
- [ ] 다른 Apple 계정으로 삭제 재인증할 때 mismatch 오류가 나타나는지 확인한다.
- [ ] provider 취소·장애·revoke 실패와 durable worker 재시도를 확인한다.
- [ ] 웹에서 정상 팝업 인증 응답, 취소, 위조 `state`, nonce 불일치와 잘못된 `iss`·audience·서명·만료·재사용 token이 각각 안전하게 처리되는지 확인한다.
- [ ] 웹에서 Apple 연결 해제를 실행해 revoke 성공·실패 때 로컬 mapping 보존 규칙이 앱과 같은지 확인한다.
- [ ] 운영 설정을 배포한 `https://dutypark.o-r.kr`에서 Apple 로그인 팝업 응답과 서버 credential 교환을 실행한다. `http://localhost`와 IP 주소는 Apple Return URL로 등록할 수 없으므로 로컬은 mock·자동 테스트와 빌드까지만 수행하고 실제 계정 E2E 근거로 사용하지 않는다.
- [ ] development 실기기와 내부 TestFlight에서 각각 서명·capability·운영 API 흐름을 확인한다.

### 심사 자료

- [ ] App Review Notes에 iOS 앱·웹 Apple 신규 가입과 계정 연결·해제, iOS 계정 삭제 재인증의 정확한 경로를 적는다.
- [ ] Apple 이름·이메일 scope를 요청하지 않으며 Dutypark 가입 화면에서 이름과 동의를 직접 받는다고 설명한다.

## 완료 조건

- 운영 비밀이 안전하게 주입된 서버에서 실제 Apple 계정의 가입·로그인·연결·해제·탈퇴가 동작한다.
- 앱과 웹에서 같은 Apple 계정이 같은 Dutypark 회원으로 이어지고, 어느 한쪽에서 만든 Apple-only 계정도 다른 쪽에서 로그인할 수 있다.
- App Store distribution 서명 Archive의 Bundle ID, Team, provisioning profile과 Apple entitlement가 일치한다.
- 웹 Services ID, Website URL, Return URL과 primary App ID 그룹 연결이 운영 값과 일치한다.
- 취소, 충돌, 계정 불일치, state·nonce·token 검증 실패, provider 장애와 revoke 재시도가 웹·실기기·TestFlight에서 예상한 오류와 복구 흐름을 보인다.
- 심사자가 Review Notes만으로 Apple 관련 흐름을 재현할 수 있다.

## 변하지 않는 정책과 계약

- Apple 로그인과 기존 계정 연결 진입점은 iOS 앱과 웹에 모두 제공한다. 웹은 Services ID와 등록된 HTTPS Return URL로 Apple JS 인증을 수행하고 credential 교환·검증은 서버가 처리한다.
- 로컬 웹은 Apple 환경값을 비워 버튼을 비활성화하고 mock·자동 테스트와 빌드만 수행한다. 실제 Apple 계정 E2E는 운영 Services ID와 `https://dutypark.o-r.kr/auth/apple/callback`을 등록·배포한 뒤 운영 HTTPS 도메인에서 수행한다.
- Services ID는 primary App ID와 그룹으로 연결해 앱과 웹에서 동일한 Apple 계정이 동일한 `sub`를 사용해야 한다.
- Apple 계정 연결과 revoke-first 연결 해제는 iOS 앱과 웹에 모두 제공한다. Apple 계정 삭제 재인증은 iOS 앱에서만 제공하고, 웹의 Apple-only 계정 삭제에는 iOS에서 진행해야 한다는 안내를 제공한다.
- Team ID는 `2V47G42CDS`, Explicit App ID와 native client ID는 `io.github.shanepark.dutypark`, 웹 client ID는 Services ID `io.github.shanepark.dutypark.web`이다.
- Apple 이름·이메일 scope를 요청하지 않는다. 검증된 Apple `sub`만 공급자 내부 식별자로 저장하고 이메일이나 이름으로 계정을 자동 병합하지 않는다.
- 신규 Apple 사용자는 기존 Dutypark 가입 화면에서 이름과 필수 약관·개인정보 동의를 직접 완료한다.
- iOS와 웹의 `LOGIN`, `LINK` 목적은 서로 바뀌어 소비될 수 없으며 `DELETE_ACCOUNT`는 iOS에서만 사용할 수 있다.
- 서버는 플랫폼별 허용 audience, `alg`, `kid`, JWKS 서명, `iss`, `exp`, `iat`, SHA-256 nonce와 token replay를 검증한다.
- Apple JWKS는 6시간 캐시하고 캐시에 없는 `kid`는 즉시 한 번 갱신하되, 계속 알 수 없는 `kid`가 들어오면 1분 동안 추가 JWKS 조회를 제한한다.
- 웹은 Apple JS SDK의 팝업 방식으로 인증하고 브라우저의 암호학적 난수로 `state`와 nonce를 만들어 메모리에만 유지한다. 팝업 응답의 `state`는 credential 교환 전에 일치해야 하고, 서버는 SHA-256 nonce, token claim·재사용, 웹 client ID와 등록된 Return URL을 검증한다.
- 웹 Apple exchange는 일회용 identity token·authorization code를 소비하므로 401 응답을 세션 refresh 뒤 자동 재전송하지 않는다. 사용자는 새 Apple 인증 시도로만 다시 진행한다.
- authorization code 교환 결과의 `sub`는 최초 identity token의 `sub`와 같아야 한다.
- Apple refresh token은 AES-256-GCM으로 암호화하고 발급에 사용한 native 또는 web client ID와 함께 별도 저장한다. 구형 `client_id IS NULL` credential은 native client credential로 호환 처리하며, 연결 해제·탈퇴 때 같은 `sub`의 모든 credential을 각각의 발급 client ID로 revoke한다. 기기와 웹 저장소에는 Apple credential을 영속화하지 않는다.
- Apple `LINK`가 token 교환 뒤 실패하면 새 refresh token을 즉시 보상 revoke한다. 그 revoke도 실패하면 본래 오류를 유지하면서 암호화된 고립 credential을 별도 트랜잭션으로 저장하고, 1일이 지난 고립 credential을 일일 정리 작업에서 revoke 성공 후 삭제한다.
- 연결 해제와 회원 탈퇴는 provider revoke 성공 전 로컬 mapping을 삭제하지 않는 revoke-first 규칙을 지킨다.
- 마지막 소셜 인증 수단의 연결 해제, 보조 계정과 impersonation 제한은 기존 서버 계약을 따른다.

## 구현 위치

- 서버 API: [`MobileOAuthController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/MobileOAuthController.kt)
- 웹 서버 API: [`WebAppleOAuthController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/WebAppleOAuthController.kt)
- Apple 검증·교환: [`security/oauth/apple`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple)
- 웹 Apple 교환: [`AppleWebOAuthService.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleWebOAuthService.kt)
- credential migration: [`V2.2.31__add_apple_sign_in_credentials.sql`](../../../src/main/resources/db/migration/v2/V2.2.31__add_apple_sign_in_credentials.sql)
- credential client ID migration: [`V2.2.34__store_apple_oauth_credential_client_id.sql`](../../../src/main/resources/db/migration/v2/V2.2.34__store_apple_oauth_credential_client_id.sql)
- 웹 Apple 개인정보 처리방침 migration: [`V2.2.35__publish_web_apple_sign_in_privacy_policy.sql`](../../../src/main/resources/db/migration/v2/V2.2.35__publish_web_apple_sign_in_privacy_policy.sql)
- iOS 인증: [`AppleSignInClient.swift`](../../Dutypark/Features/Auth/AppleSignInClient.swift)
- 로그인 화면: [`LoginView.swift`](../../Dutypark/Features/Auth/LoginView.swift)
- 웹 로그인 화면: [`LoginView.vue`](../../../frontend/src/views/auth/LoginView.vue)
- 웹 Apple 인증: [`useApple.ts`](../../../frontend/src/composables/useApple.ts)
- 웹 회원 화면: [`MemberView.vue`](../../../frontend/src/views/member/MemberView.vue)
- 웹 삭제 화면: [`AccountDeletionModal.vue`](../../../frontend/src/components/member/AccountDeletionModal.vue)
- 연결·해제: [`SettingsView.swift`](../../Dutypark/Features/Settings/SettingsView.swift)
- 삭제 재인증: [`AccountDeletionView.swift`](../../Dutypark/Features/Settings/AccountDeletionView.swift)
- entitlement: [`Dutypark.entitlements`](../../Dutypark/Dutypark.entitlements)

### 자동 검증 위치

- iOS Apple 인증 회귀 테스트: [`AppleSignInClientTests.swift`](../../DutyparkTests/AppleSignInClientTests.swift)
- 웹 Apple SDK·state·nonce 테스트: [`useApple.test.ts`](../../../frontend/src/composables/useApple.test.ts)
- 웹 일회용 요청 replay 방지 테스트: [`unauthorizedRetryPolicy.test.ts`](../../../frontend/src/api/unauthorizedRetryPolicy.test.ts)
- 웹 Apple API 테스트: [`WebAppleOAuthControllerTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/WebAppleOAuthControllerTest.kt)
- native/web 교환 테스트: [`AppleNativeOAuthServiceTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleNativeOAuthServiceTest.kt), [`AppleWebOAuthServiceTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleWebOAuthServiceTest.kt)
- identity token·JWKS 테스트: [`AppleIdentityTokenVerifierTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleIdentityTokenVerifierTest.kt)
- credential 저장·migration·정리 테스트: [`AppleCredentialServiceTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleCredentialServiceTest.kt), [`AppleCredentialClientIdMigrationTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleCredentialClientIdMigrationTest.kt), [`AppleOAuthCleanupSchedulerTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleOAuthCleanupSchedulerTest.kt)
- 개인정보 처리방침 migration 테스트: [`AppleSignInPrivacyPolicyMigrationTest.kt`](../../../src/test/kotlin/com/tistory/shanepark/dutypark/policy/migration/AppleSignInPrivacyPolicyMigrationTest.kt)

## 참고

- [App Review Guidelines 4.8 — Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services)
- [Sign in with Apple REST API](https://developer.apple.com/documentation/signinwithapplerestapi)
- [Apple token revoke](https://developer.apple.com/documentation/signinwithapplerestapi/revoke_tokens)
- [TN3194: Handling account deletions and revoking tokens](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
