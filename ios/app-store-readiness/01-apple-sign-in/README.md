# 01. Sign in with Apple

> 기준일: 2026-08-12
> 우선순위: P0
> 상태: 미착수

[전체 출시 준비 체크리스트로 돌아가기](../README.md)

## 목표

카카오·네이버 같은 제3자 로그인을 제공하는 Dutypark가 Apple의 로그인 서비스 요구사항을 충족하고,
Apple 사용자도 신규 가입, 기존 계정 연결, 재로그인, 연결 해제와 회원 탈퇴를 안전하게 수행하게 한다.

## 현재 상태

- iOS 로그인 화면은 카카오와 네이버 로그인을 제공한다.
- iOS 로그인 관련 코드는 [`ios/Dutypark/Features/Auth/LoginView.swift`](../../Dutypark/Features/Auth/LoginView.swift)에 있다.
- 모바일 OAuth 처리는 [`ios/Dutypark/Features/Auth/MobileOAuthClient.swift`](../../Dutypark/Features/Auth/MobileOAuthClient.swift)에 있다.
- iOS entitlement에는 Sign in with Apple capability가 아직 선언되어 있지 않다.
- entitlement 파일은 [`ios/Dutypark/Dutypark.entitlements`](../../Dutypark/Dutypark.entitlements)이다.
- 백엔드에는 Apple identity token 검증과 Apple 계정 연결 API가 아직 필요하다.
- 이메일 로그인이 있더라도 현재 가입 방식만으로 Apple 로그인 예외 조건 충족을 가정하지 않는다.

## 확정할 결정

- [ ] Apple 로그인은 카카오·네이버와 동등한 주 로그인 수단으로 제공한다.
- [ ] Apple의 `sub`를 공급자 내부의 불변 식별자로 저장하고 이메일을 계정 키로 사용하지 않는다.
- [ ] 기존 로그인 사용자가 설정에서 Apple 계정을 연결·해제할 수 있게 할지 확정한다.
- [ ] 같은 이메일의 기존 계정이 있어도 자동 병합하지 않고 본인 확인 후 연결한다.
- [ ] Private Relay 이메일을 일반 이메일과 동일하게 허용하되 사용자에게 특성을 안내한다.
- [ ] Apple에서 이름·이메일이 오지 않는 재로그인을 정상 흐름으로 처리한다.
- [ ] 회원 탈퇴 시 Apple authorization revoke 수행 시점과 실패 재시도 정책을 정한다.
- [ ] 보조 계정과 impersonation 상태에서는 연결·해제·탈퇴 허용 범위를 정한다.

## 백엔드 체크리스트

- [ ] Apple 로그인 요청을 받을 DTO와 인증 API를 기존 모바일 OAuth 패턴에 맞게 추가한다.
- [ ] 클라이언트가 생성한 nonce의 원문 또는 검증에 필요한 안전한 상태를 짧은 수명으로 관리한다.
- [ ] identity token의 JWT 서명을 Apple JWKS 공개 키로 검증한다.
- [ ] JWT header의 `kid`와 허용 알고리즘을 검사하고 임의 알고리즘을 허용하지 않는다.
- [ ] issuer(`iss`)가 Apple의 공식 issuer인지 검증한다.
- [ ] audience(`aud`)가 Dutypark에 등록한 올바른 client identifier인지 검증한다.
- [ ] 만료(`exp`)와 발급 시각 등 시간 관련 claim을 허용 오차와 함께 검사한다.
- [ ] token의 nonce가 클라이언트 요청 nonce의 SHA-256 결과와 일치하는지 검증한다.
- [ ] 공급자 식별자는 검증된 `sub`를 저장하고 email 변경과 분리한다.
- [ ] `email_verified`와 `is_private_email`을 신뢰하기 전에 claim 형식과 값을 검증한다.
- [ ] 같은 identity token 또는 authorization code의 재사용을 제한한다.
- [ ] Apple JWKS는 적절히 캐시하고 `kid` 미일치 시 한 번 갱신하되 장애를 무한 재시도하지 않는다.
- [ ] Apple 키 조회 장애와 잘못된 토큰을 서로 다른 내부 오류로 기록한다.
- [ ] 외부 응답에는 기존 `RestExceptionControllerAdvice` 패턴의 기계 판독 가능한 오류 코드를 사용한다.
- [ ] access/refresh cookie 발급은 기존 로그인과 동일한 `CookieService` 규칙을 적용한다.
- [ ] Bearer fallback을 사용하는 기존 클라이언트 동작을 깨뜨리지 않는다.
- [ ] 신규 가입 시 필수 약관, 개인정보, AI 동의를 각각 현재 정책에 맞게 받는다.
- [ ] 기존 계정 연결은 최근 인증 또는 기존 공급자 재인증을 요구한다.
- [ ] Apple `sub` 하나가 여러 Dutypark 계정에 연결되지 않도록 DB 유일성을 보장한다.
- [ ] 이메일이 같다는 이유만으로 기존 계정을 자동 선택하거나 병합하지 않는다.
- [ ] 최초 응답의 이름·이메일이 누락되어도 저장된 사용자 정보로 재로그인을 완료한다.
- [ ] 이름은 Apple이 최초 승인 시에만 줄 수 있으므로 최초 성공 요청에서만 선택적으로 저장한다.
- [ ] Private Relay 주소를 실제 이메일 공개로 오인하거나 다른 주소로 임의 치환하지 않는다.
- [ ] 회원 탈퇴 플로우에서 Apple revoke API 호출에 필요한 authorization 정보를 안전하게 관리한다.
- [ ] revoke 성공·실패·재시도를 감사 로그에 남기되 token, code, 개인 데이터 원문은 기록하지 않는다.
- [ ] 연결 해제 후 로그인 불가능한 계정이 되지 않도록 다른 인증 수단 존재 여부를 검사한다.

## iOS 체크리스트

- [ ] Apple Developer 설정 후 Xcode target에 Sign in with Apple capability를 추가한다.
- [ ] [`ios/Dutypark/Dutypark.entitlements`](../../Dutypark/Dutypark.entitlements)의 최종 entitlement를 확인한다.
- [ ] `AuthenticationServices`의 표준 Apple 로그인 버튼을 로그인 화면에 배치한다.
- [ ] 버튼 스타일, 최소 크기, 모서리 및 문구를 Apple Human Interface Guidelines에 맞춘다.
- [ ] 로그인마다 암호학적으로 안전한 nonce와 state를 새로 생성한다.
- [ ] 요청에는 SHA-256 처리한 nonce를 보내고 서버에는 검증 가능한 원 nonce를 전달한다.
- [ ] 최초 요청에서 필요한 경우 `.fullName`과 `.email` scope를 요청한다.
- [ ] `ASAuthorizationAppleIDCredential.identityToken` 부재와 인코딩 실패를 처리한다.
- [ ] 사용자의 취소는 일반 오류 alert가 아니라 취소 가능한 정상 상태로 처리한다.
- [ ] 네트워크 실패, 서버 검증 실패, 계정 충돌을 구분 가능한 현지화 문구로 안내한다.
- [ ] 신규 가입과 기존 로그인 결과에 따라 약관 또는 앱 메인 화면으로 올바르게 이동한다.
- [ ] 앱 재실행 시 기존 cookie 세션 복원과 Apple credential 상태가 충돌하지 않게 한다.
- [ ] 설정 화면에 계정 연결 상태와 허용된 연결·해제 동작을 표시한다.
- [ ] Apple credential revoked 또는 notFound 상태의 처리 정책을 구현한다.
- [ ] VoiceOver label, Dynamic Type 주변 배치, 44pt 이상 터치 영역을 검증한다.
- [ ] 한국어·영어에서 안내와 오류 문구를 검증한다.
- [ ] token, authorization code, nonce, 이메일을 콘솔 로그에 출력하지 않는다.

## 웹 체크리스트

- [ ] 웹에도 Apple 로그인을 제공할지, iOS 전용으로 유지할지 제품 범위를 명시한다.
- [ ] 웹 제공 시 Services ID와 Return URL을 운영·개발 환경별로 정확히 등록한다.
- [ ] callback은 허용 목록의 고정 경로만 받고 사용자 입력 URL로 redirect하지 않는다.
- [ ] state를 생성·저장·검증하고 일회성으로 소비한다.
- [ ] 웹과 iOS에서 같은 Apple `sub`가 같은 Dutypark 연결 레코드를 사용하게 한다.
- [ ] Private Relay 메일 발송이 필요하면 Apple relay 도메인 등록과 발신자 설정을 검증한다.

## Apple Developer 및 App Store Connect 체크리스트

- [ ] 유료 Apple Developer Program의 실제 배포 Team을 확정한다.
- [ ] Explicit App ID에 Sign in with Apple capability를 활성화한다.
- [ ] Xcode의 Bundle ID와 Apple Developer의 App ID가 일치하는지 확인한다.
- [ ] 필요한 경우 Services ID, Website URL, Return URL을 등록한다.
- [ ] 서버용 Sign in with Apple key를 생성하고 담당자·회전·폐기 절차를 정한다.
- [ ] key 파일과 식별자는 저장소에 커밋하지 않고 배포 환경의 비밀 저장소로 공급한다.
- [ ] Development, TestFlight, App Store 빌드의 client identifier와 Team 설정을 확인한다.
- [ ] App Review Notes에 Apple 로그인 신규 가입·기존 로그인 확인 방법을 설명한다.
- [ ] 심사 계정이 필요하다면 비밀번호를 문서나 Git에 남기지 않고 별도 채널로 관리한다.

## 핵심 검증 규칙

- `JWKS`: Apple 공개 키 집합에서 token header의 `kid`에 대응하는 키를 선택한다.
- `iss`: Apple 공식 issuer와 정확히 일치해야 한다.
- `aud`: 현재 앱 또는 구성한 서비스가 기대하는 client identifier와 일치해야 한다.
- `nonce`: 요청마다 새 값이어야 하며 token claim과 서버가 받은 원 nonce의 해시를 비교한다.
- `sub`: Apple 계정 연결의 영속 키이며 email이나 display name으로 대체하지 않는다.
- 이름과 email: 최초 승인 시에만 올 수 있으므로 token 재검증 후 즉시 필요한 범위만 저장한다.
- relay email: 사용자의 이메일 비공개 선택을 존중하며 원주소 획득을 요구하지 않는다.

## 테스트 시나리오

- [ ] Apple 계정으로 처음 가입하고 이름·이메일 제공 여부별 결과를 확인한다.
- [ ] 이메일 공개와 Private Relay 선택을 각각 테스트한다.
- [ ] 같은 Apple 계정으로 재로그인하며 이름·이메일이 다시 오지 않아도 성공하는지 확인한다.
- [ ] 사용자가 로그인 시트를 취소했을 때 로그인 화면이 정상 유지되는지 확인한다.
- [ ] 잘못된 서명, `iss`, `aud`, 만료, nonce, 재사용 token을 서버가 거부하는지 확인한다.
- [ ] 기존 카카오·네이버·이메일 계정에 Apple을 안전하게 연결한다.
- [ ] 동일 이메일이지만 다른 사용자일 가능성이 있는 계정을 자동 병합하지 않는지 확인한다.
- [ ] 마지막 인증 수단 연결 해제를 막거나 대체 인증 등록을 요구하는지 확인한다.
- [ ] Apple 설정에서 앱 사용 중지를 수행한 뒤 재로그인과 앱 상태를 확인한다.
- [ ] 회원 탈퇴 후 Apple authorization revoke와 모든 Dutypark 세션 무효화를 확인한다.
- [ ] iPhone 실기기, Simulator, 내부 TestFlight에서 각각 로그인한다.
- [ ] 오프라인, 느린 네트워크, Apple 키 조회 장애, 백엔드 5xx에서 복구 UX를 확인한다.

## 완료 조건

- [ ] Apple 로그인으로 신규 가입, 재로그인, 기존 계정 연결이 운영 유사 환경에서 성공한다.
- [ ] 서버 단위·통합 테스트가 서명과 모든 필수 claim의 실패 경로를 포함한다.
- [ ] `sub` 유일성과 계정 충돌 정책이 DB와 서비스 계층에서 강제된다.
- [ ] 최초 이름·이메일 누락과 Private Relay 사용이 정상 처리된다.
- [ ] 회원 탈퇴 시 revoke와 세션·푸시 정리가 검증된다.
- [ ] Release Archive에 올바른 entitlement가 포함된다.
- [ ] 심사자가 별도 설명 없이 Apple 로그인 버튼과 가입 흐름을 찾을 수 있다.
- [ ] 로그, 문서, Git 이력에 key, token, code, nonce 원문 등 비밀값이 없다.

## 공식 참고 링크

- [App Review Guidelines 4.8 — Login Services](https://developer.apple.com/app-store/review/guidelines/#login-services)
- [Sign in with Apple 개요](https://developer.apple.com/sign-in-with-apple/)
- [Sign in with Apple REST API](https://developer.apple.com/documentation/signinwithapplerestapi)
- [Apple로 로그인하여 사용자 인증](https://developer.apple.com/documentation/authenticationservices/authenticating-users-with-sign-in-with-apple)
- [Apple 로그인 사용자 변경 사항 전달](https://developer.apple.com/documentation/signinwithapple/processing-changes-for-sign-in-with-apple-accounts)
