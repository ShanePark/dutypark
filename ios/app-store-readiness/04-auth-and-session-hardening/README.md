# 04. 인증·세션 보강

> 상태: 웹·모바일 OAuth와 세션 장애·복구 코드 보강 완료 / 실제 네트워크와 운영 cookie·CORS 검증 대기
> 우선순위: P0
> 최종 확인일: 2026-08-14

[출시 준비 목록으로 돌아가기](../README.md)

## 남은 체크리스트

### P0: 기존 웹 OAuth 보강

- [x] 웹 Kakao·Naver OAuth도 서버가 생성한 암호학적 무작위 `state`를 사용한다.
- [x] `state`에 요청 세션, provider, `LOGIN`/`LINK` 목적, 만료와 일회 소비 상태를 묶고 서버에서 검증한다.
- [x] 연결 시작과 callback 시점의 로그인 회원이 동일한지 다시 확인한다.
- [x] 클라이언트 입력 `callbackUrl`을 제거하거나 고정 origin·callback path allowlist로 제한한다.
- [x] `referer`는 검증된 내부 상대 경로만 허용하고 scheme, host, `//`, 역슬래시와 인코딩 우회를 거부한다.
- [x] 잘못된·만료된·재사용된 state는 외부 URL로 redirect하지 않고 안전한 내부 오류 화면으로 보낸다.
- [x] Kakao·Naver 양쪽에 login CSRF, login swapping, open redirect와 state 재사용 회귀 테스트를 추가한다.

### 세션 장애와 복구

- [x] 앱 시작 시 401 또는 유효 refresh 없음은 정상 guest 상태로 처리한다.
- [x] timeout, 오프라인과 5xx는 세션 확인 실패를 알리되 guest 공개 기능과 로그인 진입을 막지 않는다.
- [x] 복구 뒤 기존 cookie로 사용자가 모르게 guest에서 authenticated로 바뀌지 않도록 전환 정책을 정한다.
- [x] 인증이 필요한 deep link는 로그인 성공 뒤 한 번만 소비하고 실패·취소 때 안전하게 보존 또는 폐기한다.
- [ ] 로그아웃 중 오프라인, timeout, 401, 5xx와 서버 logout 실패를 실제 네트워크 조건에서 검증한다.
- [x] 서버 logout 실패 후 로컬 상태는 정리됐지만 서버 세션이 남을 수 있음을 사용자에게 알리고, 다른 기기·세션 목록에서 폐기할 수 있게 한다.
- [x] APNs unregister, 서버 logout, 로컬 cookie·cache·impersonation 정리 순서를 모든 로그아웃·세션 만료 경로에서 일관되게 적용한다.
- [ ] 운영 cookie의 `Secure`, `HttpOnly`, `SameSite`, domain/path와 CORS 설정을 웹·앱 흐름에 맞춰 확인한다.
- [x] 프록시의 `Host`와 forwarded header가 OAuth callback base URL을 오염시키지 않는지 검증한다.

## 완료 조건

- 일반 사용자와 관리자 API 어느 곳에서도 refresh token 원문을 반환하거나 기록하지 않는다.
- 웹 OAuth의 위조·재사용 state, 로그인 목적 혼동과 외부 redirect가 모두 서버에서 거절된다.
- 401, 오프라인, timeout과 5xx에서 앱이 무한 복원·refresh 루프에 빠지지 않고 guest 또는 명확한 복구 화면으로 이동한다.
- 서버 logout 실패에도 로컬 인증은 안전하게 정리되고 남은 서버 세션 위험과 폐기 수단이 사용자에게 제공된다.
- 운영과 같은 callback, cookie, proxy와 네트워크 조건에서 위 계약을 재현한다.

## 변하지 않는 정책과 계약

- iOS Kakao·Naver 모바일 OAuth는 PKCE S256, 서버 생성 무작위 state, 짧은 만료와 일회성 callback·교환 코드를 사용한다.
- 모바일 callback은 `dutypark://oauth/callback`의 scheme, host와 path 계약을 따른다.
- provider, 목적, 만료와 미사용 여부가 일치하지 않는 state·교환 코드는 거절한다.
- OAuth code, state, verifier, 교환 코드와 인증 cookie는 로그·오류 메시지·분석 이벤트에 기록하지 않는다.
- 사용자가 provider sheet를 취소한 것은 세션 실패가 아니라 재시도 가능한 취소로 처리한다.
- 서버 logout 성공 여부와 관계없이 iOS는 Dutypark access/refresh cookie, URL cache, refresh 상태와 impersonation 상태를 정리하고 guest로 전환한다.
- 인증 token은 HttpOnly cookie로 관리하며 iOS UserDefaults나 웹 localStorage에 저장하지 않는다.
- 로그인 목적과 계정 연결 목적은 서로 바뀌어 소비될 수 없다.
- 새 access token은 refresh session ID에 묶고 해당 session 폐기·만료 뒤 즉시 거절한다.
- 배포 전에 발급된 session ID 없는 access token은 자체 만료까지만 허용하고 기존 refresh session은 강제로 폐기하지 않는다.
- 웹 OAuth 시작은 인증 여부와 관계없이 공유 저장소의 IP별·전역 rate limit을 통과한 뒤에만 HTTP session과 transaction을 만든다.

## 구현 위치

- refresh token DTO: [`RefreshTokenDto.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/domain/dto/RefreshTokenDto.kt)
- 사용자 세션 API: [`RefreshTokenController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/controller/RefreshTokenController.kt)
- 관리자 세션 API: [`AdminController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/admin/controller/AdminController.kt)
- 웹 OAuth callback: [`OAuthController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthController.kt)
- 웹 OAuth transaction: [`WebOAuthService.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/web/WebOAuthService.kt)
- access token session binding: [`JwtProvider.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/service/JwtProvider.kt)
- 모바일 OAuth: [`MobileOAuthService.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/mobile/MobileOAuthService.kt)
- iOS 세션: [`SessionStore.swift`](../../Dutypark/Core/Auth/SessionStore.swift)
- iOS 시작 상태: [`AppRootView.swift`](../../Dutypark/Features/Auth/AppRootView.swift)
- iOS 로그인: [`LoginView.swift`](../../Dutypark/Features/Auth/LoginView.swift)

## 참고

- [RFC 7636: OAuth PKCE](https://www.rfc-editor.org/rfc/rfc7636)
- [RFC 9700: OAuth 2.0 Security Best Current Practice](https://www.rfc-editor.org/rfc/rfc9700)
- [Apple: ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
