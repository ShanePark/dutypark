# 인증·세션 보강 계획

- 작성일: 2026-08-12
- 우선순위: P0(출시 전 보안·복구 흐름 확정)
- 범위: iOS 로그인, 모바일 OAuth, 기존 웹 OAuth, 쿠키 세션, 계정 복구

## 목표

로그인 성공뿐 아니라 취소, 재시도, 네트워크 단절, 세션 만료, 로그아웃 실패까지 예측 가능한 상태로 만든다.
모바일 OAuth의 현재 안전장치는 유지하고, 기존 웹 OAuth에서 신뢰할 수 없는 `state`와 리디렉션 값을 받는 경로를 닫는다.

## 현재 확인된 상태

- iOS 모바일 OAuth는 [MobileOAuthClient.swift](../../Dutypark/Features/Auth/MobileOAuthClient.swift)에서 PKCE S256 verifier/challenge를 생성한다.
- 서버는 [MobileOAuthService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/mobile/MobileOAuthService.kt)에서 무작위 `state`를 해시로 보관하고 5분 뒤 만료시킨다.
- 같은 서비스가 callback state를 행 잠금 후 한 번만 소비하고, 2분짜리 교환 코드를 발급하며 교환 코드도 한 번만 소비한다.
- callback URI는 현재 `dutypark://oauth/callback` 하나로 제한되어 임의 callback을 허용하지 않는다.
- [MobileOAuthController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/MobileOAuthController.kt)가 성공한 교환 뒤 HttpOnly 인증 쿠키를 설정한다.
- 즉, 모바일 Kakao/Naver 경로의 state, PKCE, 짧은 수명, 일회성 코드는 좋은 기준선이다.
- 반면 기존 웹 [OAuthController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthController.kt)는 클라이언트가 보낸 JSON/Base64 `state`를 검증 없이 파싱한다.
- 그 안의 `referer`, `callbackUrl`, `login` 값을 신뢰하여 로그인·연결 분기와 최종 이동 위치를 결정한다.
- [OAuthCallbackRedirectBuilder.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/OAuthCallbackRedirectBuilder.kt)도 전달받은 callback URL로 URI를 구성한다.
- 이 구조는 외부 사이트로 보내는 open redirect와 로그인 CSRF/login swapping 가능성을 별도 검토해야 한다.
- [SessionStore.swift](../../Dutypark/Core/Auth/SessionStore.swift)는 로그아웃 API 오류를 `try?`로 버리고 즉시 guest로 전환한다.
- 서버가 쿠키 삭제에 실패하면 UI만 로그아웃되고 쿠키 세션이 남을 수 있다.
- 앱 시작 시 [AppRootView.swift](../../Dutypark/Features/Auth/AppRootView.swift)는 세션 복원 네트워크 오류를 전체 화면 재시도로 표시한다.
- 이때 로그인 없이 쓸 수 있는 guest 화면도 열리지 않는다.
- iOS [LoginView.swift](../../Dutypark/Features/Auth/LoginView.swift)에는 이메일 로그인은 있지만 비밀번호 찾기·재설정 진입점이 없다.

## 해야 할 일

### 1. 모바일 OAuth 기준선 고정

- [ ] `state`의 provider, purpose, 만료, 미사용 여부 검사를 계속 서버 트랜잭션 안에서 수행한다.
- [ ] PKCE는 S256만 허용하고 verifier 길이·문자 집합 validation을 DTO 계층에서도 명시한다.
- [ ] callback state와 교환 코드는 재사용 시 항상 같은 일반화된 오류 코드로 거절한다.
- [ ] 로그인과 계정 연결 트랜잭션이 서로 바뀌어 소비되지 않는지 테스트한다.
- [ ] callback URL scheme/host/path를 iOS와 서버 양쪽에서 정확히 일치시킨다.
- [ ] OAuth code, state, verifier, 교환 코드, 쿠키 값을 로그·분석 이벤트·오류 메시지에 남기지 않는다.
- [ ] 앱 전환 중 취소와 provider 오류는 세션 실패가 아닌 재시도 가능한 사용자 취소로 처리한다.

### 2. 기존 웹 OAuth 보강

- [ ] 브라우저 OAuth도 서버가 생성한 암호학적 무작위 state를 사용한다.
- [ ] state 원문 대신 서버 저장 트랜잭션 또는 서명·암호화된 불투명 토큰을 사용한다.
- [ ] state에 요청 세션, provider, LOGIN/LINK 목적, 만료 시간, 일회 소비 상태를 묶는다.
- [ ] 로그인 callback에서 이미 로그인된 브라우저 상태를 임의 입력으로 바꾸지 못하게 한다.
- [ ] 연결(LINK)은 시작 시점과 callback 시점에 같은 회원 세션인지 다시 확인한다.
- [ ] `callbackUrl`은 제거하거나 앱의 고정 origin과 고정 callback path allowlist로 제한한다.
- [ ] `referer`는 상대 경로만 허용하고 `//`, scheme, host, 역슬래시, 인코딩 우회를 거부한다.
- [ ] 최종 redirect 생성은 문자열 조립 대신 검증된 내부 경로 전용 함수 하나로 중앙화한다.
- [ ] 잘못되거나 만료·재사용된 state는 외부 URL로 redirect하지 말고 안전한 로그인 오류 화면으로 보낸다.
- [ ] Kakao와 Naver 양쪽에 같은 보안 계약과 회귀 테스트를 적용한다.

### 3. 로그아웃과 로컬 쿠키 처리

- [ ] 로그아웃 진입점을 하나로 모아 APNs 해제와 서버 로그아웃 순서를 일관되게 적용한다.
- [ ] 서버 응답 성공 시 서버가 access/refresh 쿠키 모두 만료했는지 확인한다.
- [ ] 요청 실패 시 "서버 로그아웃 미완료"를 알리고 재시도 또는 기기 내 데이터 정리 선택지를 제공한다.
- [ ] APIClient가 사용하는 `HTTPCookieStorage`에서 Dutypark 인증 쿠키를 명시적으로 정리할 수 있는 함수를 둔다.
- [ ] 로컬 정리를 선택했다면 다음 실행에서 남은 refresh cookie로 자동 재로그인되지 않아야 한다.
- [ ] 로그아웃 도중 네트워크 단절, 401, 5xx, timeout을 각각 테스트한다.
- [ ] impersonation 세션 로그아웃도 원 계정과 보조 계정의 토큰 정책에 맞게 검증한다.

### 4. 앱 시작과 guest 폴백

- [ ] 401/유효 refresh 없음은 즉시 정상 guest 상태로 분류한다.
- [ ] timeout·오프라인·5xx는 "세션 확인 보류"로 분류하되 guest 공개 기능 진입을 막지 않는다.
- [ ] 재시도 버튼과 로그인 버튼을 함께 제공하고, 복구 뒤 인증 화면으로 자연스럽게 승격한다.
- [ ] 인증이 필요한 deep link는 보류했다가 로그인 성공 뒤 한 번만 소비한다.
- [ ] guest로 진행한 뒤 네트워크 회복 시 기존 쿠키로 조용히 계정을 바꾸지 않도록 사용자 경험을 정한다.

### 5. 이메일 계정 복구

- [ ] iOS 로그인 화면에 "비밀번호를 잊으셨나요?" 진입점을 추가한다.
- [ ] 이메일 존재 여부를 노출하지 않는 동일 응답과 rate limit을 사용한다.
- [ ] 재설정 토큰은 짧은 수명, 일회 사용, 안전한 해시 저장을 적용한다.
- [ ] 메일 링크는 Universal Link를 우선하고 미설치 시 웹 재설정으로 폴백한다.
- [ ] 소셜 전용·Apple relay 이메일 계정에는 가능한 복구 방법을 명확히 안내한다.
- [ ] 비밀번호 변경 뒤 기존 refresh session을 전부 폐기할지 정책을 문서화한다.

## 구현 대상 파일

- iOS: [MobileOAuthClient.swift](../../Dutypark/Features/Auth/MobileOAuthClient.swift), [SessionStore.swift](../../Dutypark/Core/Auth/SessionStore.swift), [AuthService.swift](../../Dutypark/Core/Auth/AuthService.swift)
- iOS UI: [LoginView.swift](../../Dutypark/Features/Auth/LoginView.swift), [AppRootView.swift](../../Dutypark/Features/Auth/AppRootView.swift)
- 서버: [OAuthController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthController.kt), [MobileOAuthService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/mobile/MobileOAuthService.kt)
- 쿠키: [CookieService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/service/CookieService.kt), [AuthController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/AuthController.kt)
- 웹 시작점: [LoginView.vue](../../../frontend/src/views/auth/LoginView.vue), [OAuthCallbackView.vue](../../../frontend/src/views/auth/OAuthCallbackView.vue)

## 테스트 계획

- [ ] [MobileOAuthClientTests.swift](../../DutyparkTests/MobileOAuthClientTests.swift)에 callback scheme/host/path, 취소, 오류, PKCE 케이스를 추가한다.
- [ ] [MobileOAuthControllerTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/MobileOAuthControllerTest.kt)에 만료·재사용·provider/purpose 불일치를 추가한다.
- [ ] [OAuthControllerTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthControllerTest.kt)에 외부 callback/referer, protocol-relative URL, 이중 인코딩을 추가한다.
- [ ] iOS 세션 테스트에 restore 401, offline, timeout, 5xx와 logout 실패 뒤 쿠키 상태를 추가한다.
- [ ] 실기기에서 Kakao/Naver 신규 가입, 기존 로그인, 취소, 계정 연결, 중복 연결을 운영과 같은 redirect URI로 확인한다.
- [ ] 이메일 재설정 메일의 만료·재사용·다른 기기·앱 미설치 흐름을 확인한다.

## 운영 검증

- [ ] 운영 OAuth 콘솔의 callback URL이 서버 고정 callback과 정확히 일치한다.
- [ ] 운영 CORS, cookie domain, `Secure`, `HttpOnly`, `SameSite` 값이 앱과 웹 흐름에 맞다.
- [ ] 프록시 환경에서 callback base URL이 공격자 `Host`/forwarded header로 오염되지 않는다.
- [ ] 민감값 없는 구조화 로그로 callback 실패율과 재사용 탐지만 관찰한다.
- [ ] App Review 계정은 만료되지 않고, 심사 메모에 로그인·복구 절차를 적는다.

## 완료 조건

- [ ] 모바일 OAuth의 state/PKCE/일회 코드 보장이 자동 테스트로 고정된다.
- [ ] 웹 OAuth의 외부 redirect와 위조·재사용 state가 모두 거절된다.
- [ ] 로그아웃 API가 실패해도 사용자가 남은 세션 위험을 인지하고 안전하게 정리할 수 있다.
- [ ] 시작 네트워크 오류가 guest 공개 기능을 막지 않는다.
- [ ] 이메일 사용자는 앱에서 계정 복구를 시작하고 끝낼 수 있다.
- [ ] 테스트 환경과 운영 환경에서 동일한 인증 체크리스트를 통과한다.

## 참고

- [Apple: ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [RFC 7636: OAuth PKCE](https://www.rfc-editor.org/rfc/rfc7636)
- [RFC 9700: OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700)
