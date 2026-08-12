# 개인정보 처리방침, App Privacy, 제3자 AI 동의

- 기준일·최종 확인일: 2026-08-13
- 우선순위: 제출 전 필수
- 상태: 저장소 구현 진행 완료 단계 / 외부 운영·법률·Release 확인 대기
- 관련 심사 항목: App Review Guidelines 5.1.1, 5.1.2

## 목표와 상태 요약

Dutypark의 실제 수집·저장·전송 동작을 개인정보 처리방침, 선택 동의, Privacy Manifest와 App Store Connect App Privacy에 일치시킨다. 일정 날짜·내용이 Google Generative Language API로 전송되기 전에 제공자·목적·범위를 알리고 명시적 선택 동의를 받으며, 거부하거나 철회해도 날짜와 시간을 직접 입력할 수 있어야 한다.

| 범위 | 상태 | 근거·남은 일 |
|---|---|---|
| 실제 개인정보 데이터 흐름 고지 | [x] | [V2.2.28](../../../src/main/resources/db/migration/v2/V2.2.28__align_privacy_policy_with_current_data_flows.sql)에 HttpOnly cookie, 기기 저장소, push, 첨부, Kakao/Naver, Google AI와 보유·정리 흐름을 새 정책 버전으로 추가했고 migration test 2/2가 통과했다. |
| 최신 이용약관·AI 선택 정책 | [x] | [V2.2.29](../../../src/main/resources/db/migration/v2/V2.2.29__add_terms_and_ai_schedule_consent.sql)에 `TERMS`와 `AI_SCHEDULE_PARSING` 2026-08-13 버전을 추가했다. migration test와 consent·policy·OAuth·schedule 통합 targeted command가 `BUILD SUCCESSFUL`로 통과했다. |
| 서버 동의·전송 gate | [x] | 조회·부여·철회 API, owner 기준 저장 gate, 재기동 queue 복원 gate와 worker 외부 호출 직전 재검사가 구현됐다. core consent 20 tests와 consent·policy·OAuth·schedule 통합 targeted command가 성공했다. |
| 웹 선택 동의·철회 | [x] | 설정에서 사전 opt-in/철회, 상세 정책과 수동 시간 입력 안내를 한국어·영어로 제공한다. 격리 후보 기준 type-check, Vitest 24 files/110 tests, production build가 통과했다. |
| iOS 선택 동의·철회 | [x] | 설정 toggle·상세 정책과 all-day 일정 저장 시 명시적 선택, 수동 시간 fallback을 구현했다. generic iOS Simulator build, `plutil`, `AIScheduleParsingConsentTests` 8/8이 통과했다. |
| Privacy Manifest 수집 선언 | [x] | [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)에 현재 수집 유형과 UserDefaults required-reason API가 선언됐다. Release Archive Privacy Report 대조는 별도 대기다. |
| App Store Connect App Privacy | [ ] | 아래 입력 초안을 Release 빌드·운영 서버와 최종 대조해 App Store Connect에서 Publish해야 한다. |
| Google 운영 계약 | [!] | Cloud Billing이 활성화된 paid service이며 DPA가 적용되는 Cloud Project인지 운영자가 확인해야 한다. 확인 전 production AI 자동 인식을 사용하지 않고 unpaid service에는 일정 데이터를 전송하지 않는다. |
| 법률·해외 이전 검토 | [!] | 실제 계약 주체, 처리 국가, 보관·삭제 조건과 법정 보존 의무를 확인해 최종 고지해야 한다. 확인되지 않은 국가·기간을 발명하지 않는다. |
| Sign in with Apple | [!] | 미구현이다. 구현 시 Apple `sub`, relay email, 연결·삭제·revoke 흐름을 inventory·정책·manifest·App Privacy에 추가한다. |

## 정책 버전과 API

| 항목 | 현행 버전·경로 | 의미 |
|---|---|---|
| 개인정보 처리방침 | `PRIVACY` / `2026-08-13` / `V2.2.28` | 실제 인증·저장·push·첨부·OAuth·AI 데이터 흐름과 보유·삭제·공동 TEAM 예외 |
| 이용약관 | `TERMS` / `2026-08-13` / `V2.2.29` | 비동기 계정 삭제, 공동 데이터 보존·이관, 선택 AI와 수동 입력 |
| AI 선택 동의 안내 | `AI_SCHEDULE_PARSING` / `2026-08-13` / `V2.2.29` | Google 수신자, 일정 날짜·내용 전송, 목적, 선택·철회와 호출 직전 재검사 |
| 현재 정책 | `GET /api/policies/current`, `GET /api/policies/{type}` | 가입 및 정책 화면이 서버의 최신 버전·전문을 사용 |
| AI 동의 상태 | `GET /api/consents/ai-schedule-parsing` | 현재 정책, 동의 버전, 갱신 필요, 동의·철회 시각 조회 |
| AI 동의 변경 | `PUT /api/consents/ai-schedule-parsing` | `consented=true`에는 현재 policy version이 필요하며 철회는 `false`로 요청 |

신규 가입은 클라이언트가 제출한 `TERMS`·`PRIVACY` 버전을 서버의 current version과 대조한다. AI 동의는 필수 가입 동의에 포함하지 않는 별도 선택 동의다.

## 현재 데이터 inventory와 App Privacy 입력 초안

아래는 앱과 연결된 Dutypark 서버 및 기능 전체를 포함한 초안이다. 모든 항목의 현재 목적은 `App Functionality`, `Linked to User = Yes`, `Used for Tracking = No`다.

| App Privacy 후보 | 실제 데이터 | 목적·근거 |
|---|---|---|
| Name | 직접 가입 이름, 소셜 가입 때 이용자가 Dutypark에 직접 입력한 이름 | 계정·프로필·공유 기능 |
| Email Address | 직접 가입 이메일, 선택적 기억 이메일 | 계정 인증과 로그인 편의. Kakao/Naver 프로필 이메일은 수집하지 않음 |
| Photos or Videos | 프로필 사진, 이미지·영상 첨부 | 프로필·일정·Todo 등 첨부 기능 |
| Other User Content | 일정, D-Day, 근무표, Todo, 팀·친구 관계, 설명, 일반 파일 첨부 | 서비스 핵심 콘텐츠와 공유 기능 |
| User ID | Dutypark 회원 ID, Kakao/Naver provider와 공급자 고유 식별자 | 계정 식별·소셜 로그인. provider access token은 DB에 저장하지 않음 |
| Device ID | APNs device token | 이용자가 opt-in한 iOS push를 현재 refresh session에 귀속 |
| Other Data Types | IP 주소, User-Agent, 동의 버전·시각, 로그인 시도, refresh session과 Web Push 구독 정보 | 보안, 세션, 동의 증명, opt-in 알림과 운영 안정성 |

`PrivacyInfo.xcprivacy`의 선언 후보도 위 일곱 유형과 동일하다. `NSPrivacyTracking=false`, tracking domain 없음으로 유지한다. 새로운 광고·분석·충돌 SDK를 추가하면 이 판단을 다시 해야 한다.

Dutypark 앱에는 현재 별도의 광고, analytics, crash reporting SDK가 확인되지 않는다. 서버 파일 로그에는 IP, 이메일, User-Agent, 파일명 등 요청·처리·오류 정보가 포함될 수 있고 최대 365일 보유되므로, 이를 앱의 별도 `Diagnostics`/`Usage Data` SDK 수집과 혼동하지 않는다. App Store Connect의 정확한 분류는 Release Privacy Report와 운영 로그 구성을 기준으로 최종 확인한다.

## 실제 저장·전송·보유 흐름

- 인증은 `access_token`과 `refresh_token` HttpOnly cookie를 사용한다. 웹 localStorage와 iOS UserDefaults에 인증 토큰을 저장하지 않는다.
- 웹 localStorage와 iOS UserDefaults에는 선택 이메일, 언어·화면 상태 등 편의정보가 저장될 수 있고 iOS에는 APNs token·push preference가 포함될 수 있다.
- Web Push endpoint·p256dh·auth와 APNs device token·sandbox는 refresh session에 연결되고 해제·로그아웃·세션 삭제·만료와 provider 만료 응답 때 제거된다.
- 첨부는 원본, 파일명, MIME, 크기, 저장명·경로, thumbnail metadata, context와 uploader를 처리한다. 미완료 session은 24시간이며 매일 02시 정리한다.
- 완료 파일은 관련 `SCHEDULE`·`PROFILE`·`TEAM`·`TODO` 유지 기간 또는 개별 삭제까지 보유한다. 공동 TEAM 데이터는 계정 삭제 때 보존·이관될 수 있다.
- 로그인 시도 기록은 현재 7일, 운영 파일 로그는 최대 365일 보유한다.
- Kakao/Naver에서는 고유 식별자만 영구 저장한다. provider 프로필 이름·이메일은 수집하지 않고 access token은 식별자 조회에만 일시 사용한다.

## AI 선택 동의 semantics

- 동의 주체는 요청을 수행한 관리자나 impersonator가 아니라 일정의 owner member다.
- 현재 `AI_SCHEDULE_PARSING` 정책 버전에 대한 최신 이벤트가 `GRANTED`일 때만 유효한 동의다. 정책 버전이 바뀌면 재동의가 필요하다.
- `GRANTED`와 `REVOKED` 이벤트는 member, 정책 버전, 시각, IP와 User-Agent를 기록한다. 일정 원문, Google 요청·응답 또는 API key는 동의 감사 이벤트에 저장하지 않는다.
- 같은 상태의 grant/revoke를 반복해도 중복 이벤트를 만들지 않는 idempotent 계약이다. grant의 잘못된 policy version은 거부한다.
- 일정 생성·수정은 owner의 현행 동의가 없으면 파싱 상태를 `SKIP`으로 두고 queue에 넣지 않는다.
- 서버 재기동 때 기존 `WAIT` 작업도 owner의 현행 동의를 다시 검사하며 미동의 작업을 `SKIP`으로 분류한다.
- worker는 Google 외부 호출 직전에 owner의 현행 동의를 다시 검사한다. queue 등록 뒤 철회됐거나 버전이 바뀌면 전송하지 않는다.
- 미동의·철회 상태에서도 사용자는 날짜와 시간을 직접 입력해 일정 생성·수정을 완료할 수 있다.

웹은 설정에서 전송 전에 사전 opt-in하는 UX다. iOS는 설정 toggle과 함께 all-day 일정 저장 시 아직 동의하지 않은 이용자에게 `동의` 또는 `동의하지 않고 수동 입력`을 명시적으로 선택하게 한다. 두 플랫폼 모두 서버 계정 기준 상태를 사용한다.

## Google 운영 계약 launch blocker

Google의 [Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms)에 따르면 unpaid quota는 input/output이 제품 개선에 사용되고 human review 대상이 될 수 있으며 개인정보·기밀정보 전송이 금지된다. Billing이 활성화된 Cloud Project의 paid service는 해당 데이터를 제품 개선에 사용하지 않으며 Google의 DPA가 적용되는 계약이다.

- [!] 운영 Cloud Project에 Cloud Billing이 활성화되어 실제 호출이 paid service로 처리되는지 확인한다.
- [!] 계약 주체와 [Google Cloud Data Processing Addendum](https://cloud.google.com/terms/data-processing-addendum)이 적용되는지 확인하고 기록한다.
- [!] 확인한 paid Cloud Project의 API key만 production에 구성한다.
- [!] 위 확인 전 production AI 자동 인식을 사용하지 않고 unpaid service에는 일정 날짜·내용을 전송하지 않는다.
- [ ] Google의 실제 처리 위치·하위처리자·보관·삭제 조건과 개인정보 처리방침 고지 문구를 운영 계약 및 별도 법률 검토로 확정한다.

## 구현·검증 기록

- [x] `V2.2.28` 개인정보 처리방침 migration 적용·idempotency·핵심 문구 계약 test 2/2 통과
- [x] 웹 type-check 통과
- [x] 격리 후보 기준 웹 Vitest 24 files/110 tests 통과(AI 동의 locale 계약 포함)
- [x] 웹 production build 통과
- [x] 백엔드 core consent 20 tests 및 consent service/controller, PolicyController, `V2.2.29` migration, OAuthController, ScheduleService, QueueManager, Worker 통합 targeted command 통과 (`BUILD SUCCESSFUL`, 20초)
- [x] generic iOS Simulator build 통과, `PrivacyInfo.xcprivacy` `plutil` 검증 통과, `AIScheduleParsingConsentTests` 8/8 통과(exit 0)
- [ ] 실제 paid Google endpoint에서 테스트용 비민감 일정으로 동의 전 0건, 동의 후 1건, 철회 후 0건을 네트워크·서버 로그로 확인
- [ ] iOS에서 동의하고 웹에서 철회하는 교차 플랫폼 E2E 및 그 반대 방향 확인
- [ ] Xcode Release Archive Privacy Report와 `PrivacyInfo.xcprivacy`, App Store Connect 입력값 대조

## 제출 전 완료 조건

- [x] 개인정보 처리방침의 cookie, 저장소, push, 첨부, 소셜 로그인, AI, 계정 삭제·공동 TEAM 설명이 실제 구현과 일치한다.
- [x] Google 전송 전에 현행 정책의 제공자·목적·전송 범위를 알린 선택 동의와 서버 강제를 구현하고 백엔드·웹·iOS 자동 검증을 통과했다.
- [x] 거부·철회와 수동 시간 입력 fallback을 구현하고 백엔드·웹·iOS 자동 검증을 통과했다. 실제 교차 플랫폼 E2E는 별도 출시 검증으로 남아 있다.
- [x] Privacy Manifest에 현재 수집 데이터 유형, App Functionality, user-linked, non-tracking 선언을 추가했다.
- [ ] App Store Connect App Privacy 초안을 Release 기준으로 확정하고 Publish한다.
- [!] paid service/DPA 운영 계약, 법률·해외 이전 고지, production key 구성이 확인돼야 AI 기능을 production에서 사용할 수 있다.
- [!] Apple 로그인은 별도 구현·정책·privacy 업데이트 전까지 완료되지 않았다.

## 공식 자료

- [Apple App Review Guidelines 5.1](https://developer.apple.com/app-store/review/guidelines/#privacy)
- [Apple: Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Apple: Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
- [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Google: Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms)
- [Google Cloud Data Processing Addendum](https://cloud.google.com/terms/data-processing-addendum)
