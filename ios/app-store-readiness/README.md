# Dutypark iOS App Store 출시 준비

> 기준일: 2026-08-12
> 범위: iOS 앱의 TestFlight 검증부터 App Store 심사 및 운영 전환까지

이 디렉터리는 출시 준비 작업의 단일 진입점이다.
각 항목은 이 문서에서 상태와 우선순위를 관리하고, 구현·검증 방법은 연결된 하위 문서에서 확인한다.

## 상태 정의

- `[ ] 미착수`: 요구사항과 구현 범위를 아직 확정하지 않음
- `[-] 진행 중`: 설계·구현·검증 중이며 완료 조건을 충족하지 않음
- `[x] 완료`: 상세 문서의 완료 조건과 검증 증거를 모두 충족함
- `[!] 차단`: 외부 설정, 정책 결정, 계정 권한 등 선행 조치가 필요함
- `[~] 해당 없음`: 근거를 기록한 뒤 이번 출시 범위에서 제외함

완료 표시는 코드가 존재한다는 뜻만으로 붙이지 않는다.
실기기 또는 적절한 자동화 테스트, 운영 환경 설정, 심사 문구까지 확인해야 한다.

## 우선순위 정의

- `P0`: 미완료 시 심사 거절, 로그인 불가, 개인정보 침해 또는 출시 중단 가능성이 큼
- `P1`: 출시 전 해결해야 안정적인 테스트·운영·심사 대응이 가능함
- `P2`: 첫 제출 전 권장하며, 미완료 시 후속 개선 일정과 대응책을 남김

## 권장 진행 순서

1. 계정 생명주기 정책을 확정하고 Apple 로그인과 회원 탈퇴의 서버 계약을 먼저 설계한다.
2. 개인정보 처리방침과 제3자 AI 전송 동의를 실제 데이터 흐름에 맞춘다.
3. 인증 세션, 푸시, Universal Link처럼 환경 의존성이 큰 기능을 개발·운영 환경에서 검증한다.
4. 사용자 콘텐츠 안전장치와 접근성·현지화를 점검한다.
5. 회귀 테스트를 통과한 빌드를 TestFlight에 배포한다.
6. App Store Connect 메타데이터와 심사 계정을 준비하고 제출한다.
7. 출시 후 모니터링·롤백·지원 절차를 실제 담당자와 점검한다.

## P0 체크리스트

- [ ] Apple 로그인의 서버·iOS·콘솔 구현과 계정 연결 정책을 완료한다. ([상세](./01-apple-sign-in/README.md))
- [ ] 앱 안에서 회원 탈퇴를 시작하고 완료할 수 있게 한다. ([상세](./02-account-deletion/README.md))
- [ ] 탈퇴 시 세션, 푸시 토큰, 소셜 연결 및 소유 데이터 처리 규칙을 적용한다. ([상세](./02-account-deletion/README.md))
- [ ] 개인정보 처리방침을 실제 쿠키·푸시·첨부·소셜 로그인 데이터 흐름과 일치시킨다. ([상세](./03-privacy-and-ai-consent/README.md))
- [ ] 일정 제목을 제3자 AI에 보내기 전 대상·목적을 알리고 명시적 동의를 받는다. ([상세](./03-privacy-and-ai-consent/README.md))
- [ ] AI 처리 거부·철회 시에도 수동 일정 입력이 정상 동작하게 한다. ([상세](./03-privacy-and-ai-consent/README.md))
- [ ] 로그아웃 및 토큰 만료 후 로컬 쿠키와 서버 세션이 일관되게 무효화된다. ([상세](./04-auth-and-session-hardening/README.md))
- [ ] OAuth state, callback 대상, nonce 검증으로 로그인 CSRF와 open redirect를 차단한다. ([상세](./04-auth-and-session-hardening/README.md))
- [ ] App Store Connect의 App Privacy 답변을 실제 수집·연결·추적 행위와 일치시킨다. ([상세](./07-app-store-connect/README.md))
- [ ] 심사자가 전체 기능을 확인할 수 있는 운영 심사 계정과 Review Notes를 준비한다. ([상세](./07-app-store-connect/README.md))

## P1 체크리스트

- [ ] APNs 등록, 거부, OFF→ON, 재로그인, 다른 계정 전환 흐름을 검증한다. ([상세](./05-push-notifications/README.md))
- [ ] Sandbox APNs와 TestFlight Production APNs 설정 및 토큰 저장 환경을 분리한다. ([상세](./05-push-notifications/README.md))
- [ ] 알림 탭이 정확한 일정·Todo·친구 화면으로 이동하고 badge가 정리된다. ([상세](./05-push-notifications/README.md))
- [ ] 운영 도메인의 AASA가 redirect나 SPA HTML 없이 올바른 JSON을 반환한다. ([상세](./06-associated-domains/README.md))
- [ ] Associated Domains entitlement와 AASA의 Team ID·Bundle ID 조합을 맞춘다. ([상세](./06-associated-domains/README.md))
- [ ] 공개·친구·팀 콘텐츠에 신고, 차단, 운영 문의 및 대응 절차를 제공한다. ([상세](./10-user-generated-content/README.md))
- [ ] 사용자 콘텐츠 삭제와 제재가 관련 화면·알림·첨부파일에 함께 반영된다. ([상세](./10-user-generated-content/README.md))
- [ ] VoiceOver, Dynamic Type, 44pt 터치 영역, 색 대비를 핵심 흐름에서 확인한다. ([상세](./09-quality-accessibility/README.md))
- [ ] 한국어·영어·일본어·중국어·스페인어에서 잘림과 미번역 문구를 확인한다. ([상세](./09-quality-accessibility/README.md))
- [ ] 작은 화면과 큰 화면, 라이트·다크 모드에서 주요 화면을 실기기로 확인한다. ([상세](./09-quality-accessibility/README.md))
- [ ] 로그인 공급자별 신규 가입·기존 로그인·연결·중복 연결 테스트를 통과한다. ([상세](./08-testflight-and-review/README.md))
- [ ] 오프라인, 느린 네트워크, 401, 5xx 및 앱 재설치 상황을 검증한다. ([상세](./08-testflight-and-review/README.md))
- [ ] 실패 중인 UI 테스트를 고치고 안정적인 회귀 테스트 기준선을 만든다. ([상세](./08-testflight-and-review/README.md))
- [ ] 내부 TestFlight에서 실제 운영 서버와 Production APNs를 검증한다. ([상세](./08-testflight-and-review/README.md))
- [ ] 앱 설명, 키워드, 연령 등급, 지원 URL, 개인정보 URL을 확정한다. ([상세](./07-app-store-connect/README.md))
- [ ] 실제 앱과 동일한 언어·기기별 스크린샷과 앱 아이콘을 준비한다. ([상세](./07-app-store-connect/README.md))
- [ ] Release Archive의 서명, entitlement, privacy manifest를 검사한다. ([상세](./11-release-engineering/README.md))
- [ ] 출시·단계적 배포·중단·롤백 기준과 담당자를 정한다. ([상세](./11-release-engineering/README.md))

## P2 체크리스트

- [ ] 앱 시작 중 세션 복원 실패가 게스트 기능 전체를 막지 않도록 복구 UX를 정리한다. ([상세](./04-auth-and-session-hardening/README.md))
- [ ] 비밀번호 찾기와 계정 복구 진입점을 앱에서 명확히 제공한다. ([상세](./04-auth-and-session-hardening/README.md))
- [ ] 로그인·탈퇴·푸시·딥링크 장애를 탐지할 운영 지표와 알림을 정의한다. ([상세](./11-release-engineering/README.md))
- [ ] 고객 문의, 개인정보 삭제 요청, 심사 문의의 담당자와 응답 시간을 정한다. ([상세](./11-release-engineering/README.md))
- [ ] 첫 출시 후 크래시·인증 실패·푸시 실패를 점검할 일정을 등록한다. ([상세](./11-release-engineering/README.md))
- [ ] 심사 거절 사유와 대응 결과를 이 문서 세트에 환류한다. ([상세](./11-release-engineering/README.md))

## 상세 문서

| 순서 | 상세 문서 | 우선순위 |
| --- | --- | --- |
| 01 | [01. Sign in with Apple](./01-apple-sign-in/README.md) | P0 |
| 02 | [앱 내 계정 삭제](./02-account-deletion/README.md) | P0 |
| 03 | [개인정보 처리방침, App Privacy, 제3자 AI 동의](./03-privacy-and-ai-consent/README.md) | P0 |
| 04 | [인증·세션 보강 계획](./04-auth-and-session-hardening/README.md) | P0/P2 |
| 05 | [APNs 푸시 알림 출시 준비](./05-push-notifications/README.md) | P1 |
| 06 | [Associated Domains와 Universal Links](./06-associated-domains/README.md) | P1 |
| 07 | [Apple Developer 및 App Store Connect 제출 준비](./07-app-store-connect/README.md) | P0/P1 |
| 08 | [TestFlight 및 App Review 실행 가이드](./08-testflight-and-review/README.md) | P1 |
| 09 | [품질, 호환성 및 접근성 검증 가이드](./09-quality-accessibility/README.md) | P1 |
| 10 | [10. 사용자 생성 콘텐츠(UGC) 안전장치](./10-user-generated-content/README.md) | P1 |
| 11 | [11. 릴리스 엔지니어링과 App Store 빌드](./11-release-engineering/README.md) | P1/P2 |

## 진행 기록 규칙

- 체크 상태를 바꿀 때 관련 PR 또는 검증 기록을 항목 아래에 남긴다.
- 정책 결정에는 결정일, 결정자, 적용 범위, 예외를 기록한다.
- App Store Connect와 Apple Developer 설정은 값 자체보다 확인 위치와 담당자를 기록한다.
- Team ID, 키, 토큰, 비밀번호, 심사 계정 비밀번호 등 비밀값은 문서나 Git에 남기지 않는다.
- 스크린샷에 사용자 개인정보나 운영 인증 정보가 포함되지 않도록 확인한다.
- Apple 정책이 바뀌면 기준일을 갱신하고 공식 문서에서 변경 내용을 다시 확인한다.

## 출시 승인 기준

- P0 항목은 모두 `[x] 완료`여야 한다.
- P1 미완료 항목은 출시 책임자의 명시적 승인과 대응 계획이 있어야 한다.
- 자동화 테스트뿐 아니라 최소 한 대의 지원 실기기에서 핵심 흐름을 통과해야 한다.
- 운영 서버, Production APNs, Universal Link, 개인정보 URL이 외부 네트워크에서 접근 가능해야 한다.
- 심사 제출 빌드의 버전과 문서에 기록한 검증 빌드가 동일해야 한다.
