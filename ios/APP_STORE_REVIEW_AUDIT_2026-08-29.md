# Dutypark iOS App Store 심사 증분·최종 게이트 보고서

- 기준일: 2026-08-29 (KST)
- 판정: **READY FOR APP STORE CONNECT — 로컬 제출 준비 완료**
- 코드 기준: 최종 로컬 Archive/IPA의 clean source HEAD `0f0dd64c`. 후속 backend 개인정보 로그 보강은 `a40978c4`까지 반영됐다. 이 문서의 증거·판정 정리는 앱 바이너리를 바꾸지 않는다.
- 목적: [2026-08-28 보고서](./APP_STORE_REVIEW_AUDIT_2026-08-28.md)의 반복이 아닌, 그 이후 변경분과 제출 직전의 미검증 게이트를 기록한다.
- 비밀값: 비밀번호, private key, client secret, webhook token, 실제 S2S URL은 이 문서에 기록하지 않는다. 심사용 계정은 App Store Connect의 `App Review Information → Sign-in required → Username / Password` 필드에서만 제공한다.

## 1. 최종 판정

코드·스크린샷·배포 IPA에 대한 로컬 검증은 완료됐다. 남은 일은 인증된 App Store Connect에서만 할 수 있는 제출 입력과 업로드이며, 내부 QA 권고사항을 이유로 제출 자체를 막지 않는다.

| 항목 | 현재 판단 | 남은 제출 작업 |
|---|---|---|
| 제품·개인정보·계정 삭제 | 자동 검증 PASS | 초안 내용을 App Store Connect Privacy Details에 저장 |
| App Store 스크린샷 | 최신 ko/en 세트 재촬영·재합성·시각 검토 PASS | 준비된 12개 이미지를 등록 |
| 배포 IPA | clean `0f0dd64c` Archive/export 및 로컬 검사 PASS | App Store Connect에 업로드하고 processing 완료 확인 |
| Review Notes·심사 계정 | 저장소 입력 초안 작성 | Review Notes와 secure username/password 필드 저장, 심사 기간 중 계정·backend 유지 |
| 연령 등급 | 코드 기준 답변 초안 작성 | 현재 질문지에 답하고 계산된 등급 저장 |

Apple은 앱 완성도, 개인정보처리방침, 계정 삭제, UGC, 메타데이터를 실제 앱에서 확인할 수 있다. 다만 내부 DB 직접 감사, 특정 테스트 종류, 실기기 전수 E2E, raw 테스트 번들의 장기 보관까지 제출 조건으로 요구하지는 않는다.

Apple routine review의 경계도 구분한다. Apple이 내부 DB를 직접 조회·감사한다고 전제하지 않으며, 이 보고서의 제출 기준은 배포 환경에서 관찰 가능한 live-backend flow와 앱·App Store Connect Privacy Details·개인정보처리방침의 선언이 서로 일치하는지 확인하는 것이다. 내부 DB/SQL·xcresult는 Dutypark의 traceability와 release evidence일 뿐 Apple의 직접 DB audit 결과로 표현하지 않는다.

## 2. 2026-08-29 검증 결과

이번 변경분에 대해 자동 검증은 다음과 같이 완료됐다. 아래 PASS는 실행한 테스트와 산출물에만 적용하며 외부 서비스나 실기기의 모든 동작을 증명한다는 뜻은 아니다.

| 범위 | 결과 | 비고 |
|---|---|---|
| iOS UI baseline | 91개 중 89 PASS, `tab.more` 및 알림 닫기 selector lookup failures 2건; 앱 crash 0, runner/simulator 오류 0 | geometry 문제가 아니라 selector lookup 실패였다. 후속 `7788a8f3`에서 selector fallback/accessibility id를 수정하고 해당 두 테스트를 각각 RED→GREEN focused PASS. 나머지 89개 전체 재실행은 생략 |
| UI 안정화 1 | `ios/DutyparkUITests/AccountDeletionParityUITests.swift` | RED→GREEN focused PASS |
| UI 안정화 2 | `ios/DutyparkUITests/NotificationConfirmationVisualUITests.swift` | RED→GREEN focused PASS |
| iOS `DutyparkTests` 최신 실행 요약 | 1,128 total: 1,127 PASS / 1 SKIP / 0 FAIL; device-expanded 결과 1,152 PASS | Customer Support 선언 커밋 뒤 재실행했으며 당시 함께 검증한 Calendar 변경은 후속 `c01f1174`로 커밋됨. 1,128은 identifier total이고 1,152는 동적 parameter device case의 pass event 수이며 서로 더하지 않는다. SKIP 1건은 `OfflineSessionStore` first-unlock simulator file-protection을 시뮬레이터에서 재현할 수 없어 제외 |
| Release simulator build | PASS | exact `iPhone 13 mini`, iOS 26.5 |
| Debug simulator install | PASS | 위 unit-test로 검증된 앱을 exact `iPhone 13 mini`에 설치하고 app container를 확인. 기존 Release 임시 캡처는 `/private/tmp/dutypark-release-latest-20260829.png`이며 장기 보존 증거·제출물로 사용하지 않음 |
| backend full Gradle | 1,845 total; 1,824 PASS / 21 SKIP / 0 FAIL | skip 사유는 개별 Gradle 결과에서 확인 |
| Slack privacy focused | 54 PASS | 일정 파싱 33 + 문의·신고·generic argument dump·예외 payload 21 최소화 검증 |
| web full | 97 files / 727 tests PASS | type-check PASS, build PASS(2,218 modules transformed) |
| App Store screenshot capture/compose/extract | PASS | iPhone 17 Pro Max, iOS 26.5에서 실제 local demo 계정 ko/en 2/2 PASS. 14개 raw와 12개 final을 1320x2868 opaque PNG로 갱신하고 전수 시각 검토 완료 |
| iOS Customer Support privacy declaration | manifest·exact-list 테스트 보강, focused 19/19 PASS | 문의 흐름에 대응하는 `NSPrivacyCollectedDataTypeCustomerSupport`를 linked/App Functionality/not tracking으로 추가. focused RED 18 PASS/1 intended FAIL 뒤 GREEN 19/19 PASS; 전체 unit도 PASS. 상세 provenance는 evidence manifest에 기록 |
| Evidence manifest | 작성됨 | [2026-08-29 evidence manifest](./review-evidence/2026-08-29/README.md)에 fresh backend/web/iOS unit 재실행의 명령·tested SHA·결과와 기존 UI xcresult/capture provenance를 기록. raw bundle 장기 보관은 선택적 내부 감사 항목 |

## 3. 이번 점검의 범위와 근거

### 점검 범위

- 시뮬레이터 기준: unit/build는 `iPhone 13 mini`, App Store 캡처는 `iPhone 17 Pro Max`, 모두 iOS 26.5. 캡처는 `1856c2aa` 기반이고 최신 unit은 Customer Support 선언 `f03d53a2`와 Calendar 표시 `c01f1174`를 함께 검증했다. 외부·실기기·배포 검증은 별도로 남긴다.
- iOS 코드: `ios/Dutypark/` 및 `ios/DutyparkTests/`
- 백엔드 개인정보·인증·UGC 코드: `src/main/kotlin/`, `src/main/resources/db/migration/v2/`, `src/test/kotlin/`
- App Store 산출물: `docs/app-store/raw/{ko,en}/`, `docs/app-store/final/{ko,en}/`, `docs/app-store/manifests/{ko,en}.json`
- 이전 결과와 미실행 목록은 [2026-08-28 보고서](./APP_STORE_REVIEW_AUDIT_2026-08-28.md)를 기준으로 한다. 이 문서는 8/29 변경과 제출 차단 사유만 갱신한다.

### Apple 공식 기준

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [User Privacy and Data Use / ATT](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
- [Protected-resource permission guidance](https://developer.apple.com/documentation/uikit/requesting-access-to-protected-resources)

## 4. 8/29 증분 변경사항

### 4.1 Slack 운영 알림 개인정보 최소화

이전 구현은 문의·신고·일반 예외 알림에 사용자 입력, 이름, ID, 이메일, IP, 요청 본문 또는 stack trace가 섞일 수 있었다. 현재 작업 트리에는 다음 변경이 반영되어 있다.

| 변경 | 근거 경로 | 의도 | 검증 |
|---|---|---|---|
| `SlackEvent`에서 subtitle/body/footnote 제거, headline/chips만 운영 enum·고정문구로 제한 | `src/main/kotlin/com/tistory/shanepark/dutypark/common/slack/SlackEvent.kt` | 사용자·record ID가 공통 payload에 들어가지 않게 함 | **Slack focused PASS (21/21)** |
| Slack 렌더러가 사용자 본문·각주를 만들지 않도록 변경 | `src/main/kotlin/com/tistory/shanepark/dutypark/common/slack/notifier/SlackEventNotifier.kt` | 외부 채널 전송 데이터 최소화 | **Slack focused PASS (21/21)** |
| 문의 알림을 `New inquiry`와 `GUEST`/`MEMBER`만 전송 | `src/main/kotlin/com/tistory/shanepark/dutypark/inquiry/service/InquirySlackNotifier.kt` | 이메일·IP·제목·본문·member ID 제외 | **Slack focused PASS (21/21)** |
| 신고 알림을 사유/대상 type/중복·차단 enum만 전송 | `src/main/kotlin/com/tistory/shanepark/dutypark/report/service/ReportSlackNotifier.kt` | 신고자·피신고자 이름, 대상 ID, 상세내용, snapshot 제외 | **Slack focused PASS (21/21)** |
| 예외 알림을 예외 클래스명만 전송하고 요청 본문·URL·IP·User-Agent·stack trace 제거 | `src/main/kotlin/com/tistory/shanepark/dutypark/common/slack/advice/ErrorDetectAdvisor.kt` | 사용자 입력과 인증·네트워크 정보를 운영 채널로 보내지 않음 | **Slack focused PASS (21/21)** |
| `@SlackNotification`의 method argument dump 무시 및 실패 로그에서도 exception message 제외 | `src/main/kotlin/com/tistory/shanepark/dutypark/common/slack/aspect/SlackNotificationAspect.kt` | DTO·credential·사용자 문자의 우발적 전송 방지 | **Slack focused PASS (21/21)** |
| LLM 일정 파싱 실패 알림을 고정 `Failure Kind` enum만 전송 | `src/main/kotlin/com/tistory/shanepark/dutypark/schedule/timeparsing/service/ScheduleTimeParsingWorker.kt` | 일정 ID·동적 시간·사용자 입력·raw AI 응답 제외 | **Schedule parsing privacy focused PASS (33/33)** |

추가로 배포 설정·payload를 확인할 Slack sink:

- `src/main/kotlin/com/tistory/shanepark/dutypark/common/listener/ApplicationStartupShutdownListener.kt`는 branch/commit 상태 알림만 보낸다. 개인정보가 없음을 최종 payload test에서 확인한다.
- Slack을 운영 채널로 계속 사용한다면 개인정보처리방침과 App Store Connect Privacy Details를 실제 payload에 맞춰 갱신한다. 현재 payload 최소화는 자동 테스트로 검증됐으며, 운영 webhook 관찰은 비차단 운영 점검이다.

### 4.2 UGC 텍스트 필터 보강

Apple [App Review Guidelines 1.2](https://developer.apple.com/app-store/review/guidelines/)는 UGC 서비스에 게시 전 부적절한 내용 필터링 수단, 신고·신속한 대응, 사용자 차단, 공개 연락처를 요구한다. 현재 작업 트리의 증분은 다음과 같다.

| 변경 | 근거 경로 | 의도 | 검증 |
|---|---|---|---|
| 캐시가 없거나 오프라인이어도 iOS 번들 사본 또는 emergency fallback을 사용 | `ios/Dutypark/Core/ContentFilter/ContentFilterStore.swift`, `ios/Dutypark/Core/ContentFilter/banned-words.json` | iOS cold/offline launch에서 fail-open 되지 않음 | **관련 iOS focused/unit 검증 PASS** |
| 캘린더 입력을 client filter로 검사하고, D-Day는 공개일 때만 검사(private는 허용) | `ios/Dutypark/Features/Calendar/CalendarViewModel.swift` | 사용자 입력 직전 안내와 오류 haptic; private D-Day는 저장 허용 | **관련 iOS focused/unit 검증 PASS** |
| Todo, 팀, 프로필/회원가입 입력을 client filter로 검사 | `ios/Dutypark/Features/Todo/TodoViewModel.swift`; `ios/Dutypark/Features/Team/TeamViewModel.swift`; `ios/Dutypark/Features/Settings/SettingsViewModel.swift`; `ios/Dutypark/Features/Auth/SsoSignupView.swift` | 주요 공개/공유 문자열의 일관된 UX | **관련 iOS focused/unit 검증 PASS** |
| API가 동일 정규화·substring matching을 제공하고 공개 D-Day 및 근무유형/기본 근무유형 mutation을 서버에서 검증 | `src/main/kotlin/com/tistory/shanepark/dutypark/publiccontent/service/PublicContentService.kt`; `src/main/kotlin/com/tistory/shanepark/dutypark/member/service/DDayService.kt`; `src/main/kotlin/com/tistory/shanepark/dutypark/duty/service/DutyTypeService.kt`; `src/main/kotlin/com/tistory/shanepark/dutypark/team/service/TeamService.kt` | client preflight 우회 방지; private D-Day는 서버 검증 대상에서 제외 | **관련 backend focused/full 검증 PASS** |

정규화 계약은 backend와 iOS에서 code point를 기준으로 동일하게 맞춰져 있다. 입력과 목록 항목 모두 NFKC 정규화와 lowercase를 거친 뒤 Unicode letter 및 decimal digit(`Nd`)만 남기고 substring으로 비교한다. iOS는 Unicode scalar general category의 `L*`와 decimal number를 사용하고, backend는 code point 기반 letter/digit 판정을 사용한다. D-Day는 공개 항목만 이 서버·클라이언트 검사를 적용하며 private D-Day는 허용한다. 근무유형과 팀 기본 근무유형은 팀에 공유되는 이름이므로 별도의 서버 mutation 검증 대상이다.

웹도 NFKC·lowercase·Unicode letter 및 decimal digit(`Nd`) 정규화와 private D-Day 예외를 반영 완료했다. 웹 cold start에서 단어 목록 fetch가 실패하는 경우와 일부 서버 mutation의 방어 심도는 향후 보강할 수 있지만, Apple 1.2가 요구하는 사용자 신고·차단·연락처와 현재 사용자 대면 필터 흐름이 있으므로 현재 제출 차단 조건으로 두지 않는다.

세 런타임은 같은 NFKC·Unicode letter/decimal digit 규칙을 구현한다. 새 문자권 단어를 추가할 때 cross-runtime fixture를 보강하는 것은 유지보수 권고이며 제출 조건이 아니다.

자동 검증으로 확인된 현재 범위와 비차단 운영 권고:

- 공개 범위가 넓어지면 서버 mutation 적용 범위와 첨부 신고·차단·삭제 운영을 함께 확장한다.
- 중복된 금칙어 목록 소스는 다음 목록 변경 때 자동 동기화 또는 parity test로 관리한다.
- 필터만으로 모든 위해 콘텐츠를 막는다고 표현하지 않고 신고·차단·운영 대응을 함께 유지한다.

## 5. 문의·신고 보존 정책

Apple은 계정 삭제 시 계정과 관련된 데이터 및 UGC를 원칙적으로 삭제하도록 요구하고, 법적 보존 의무가 있는 경우에만 예외를 인정한다. [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)은 보존되는 정보를 사용자에게 설명하고, 단순 비활성화나 고객센터 연락만으로 대체하지 않도록 한다.

현재 `src/main/resources/db/migration/v2/V2.2.44__publish_ugc_privacy_policy.sql`은 다음을 명시한다.

- 문의 기록은 계정 삭제 후에도 보존
- 신고 기록, 신고자·피신고자 이름 snapshot, 신고 대상 콘텐츠 snapshot도 보존
- 고정된 자동 삭제 주기 없음
- 목적 달성 후 삭제 또는 익명화한다는 원칙만 존재

현재 탈퇴 전·후 UI와 공개 개인정보처리방침은 5분 ETA가 삭제 대상 계정 데이터·파일에 적용되고, 문의·신고 기록은 지원·안전·분쟁·법적 목적이 끝날 때 삭제 또는 익명화될 수 있음을 구분한다. App Store Connect에는 이 실제 동작을 그대로 선언하며, 문의·신고가 5분 안에 삭제된다고 오기하지 않는다.

고정 보존일, snapshot·식별자 최소화, legal hold 종료 조건, 관리자 접근 통제는 사업자·법무·운영이 더 엄격하게 정할 수 있는 후속 개인정보 거버넌스 항목이다. Apple 제출을 위해 특정 일수를 임의로 만들 필요는 없으므로 현재 release gate에서는 제외한다. 정책이나 서버 동작이 바뀌면 UI·Privacy Details도 함께 갱신한다.

### Apple 최소 요건과 Dutypark 내부 QA의 구분

Apple의 최소 요건은 앱 안에서 계정 삭제를 시작할 수 있고, 삭제 범위와 법적 보존 예외를 설명하며, 계정과 관련 데이터를 실제로 삭제하는 경로를 제공하는 것이다. Apple FAQ는 삭제가 즉시·자동일 필요는 없다고 설명하므로 서버의 비동기 처리 자체를 부적합으로 단정하지 않는다. 다만 비동기 처리라면 사용자에게 예상 소요시간을 알리고 삭제 완료 후 confirmation을 제공해야 한다.

현재 작업 트리는 이 제품 수준 누락을 보완했다. 클라이언트가 삭제 요청 전에 32-byte CSPRNG receipt token을 만들고 저장하며 서버는 원문 대신 SHA-256만 보관한다. 로그인 세션을 제거한 뒤에도 web과 iOS가 5초 간격으로 공개 status API를 조회하여 `PROCESSING`, 실제 worker의 `COMPLETED`, 최종 `FAILED`를 구분한다. UI에는 정상 상황에서 **보통 5분 이내**라는 ETA를 표시하고, 실제 완료 후에만 완료 confirmation과 success feedback을 제공한다. 실패·만료·알 수 없는 응답은 완료로 오인하지 않고 `/support` 안내를 제공한다. 요청이 서버에 접수됐는지 불명확한 network/5xx/응답 파싱 실패에도 요청 전 receipt를 유지하고 status 흐름으로 전환하며, ETA 전의 일시적 404는 계속 polling한다. receipt는 로컬 계정 ID에 묶어 다른 로그인 계정의 삭제 요청에 재사용하거나 덮어쓰지 않는다. terminal receipt는 완료 또는 최종 실패 후 30일 동안 상태 확인에만 사용되며, raw token은 URL·query·로그·analytics에 넣지 않는다. worker의 상태 전이는 claim별 lease token으로 보호한다.

현재 구현으로 해소된 제품 수준 범위는 삭제 요청의 ETA 안내, 로그아웃 뒤 receipt 기반 상태 조회, `COMPLETED` 완료 confirmation, `FAILED` 지원 경로와 문의·신고 보존 예외 고지다. backend·web·iOS 자동 테스트가 이 계약을 검증한다. 운영 환경의 disposable-account 확인과 edge rate limit 점검은 권장 QA이지만 App Store 제출 차단 조건은 아니다.

## 6. 최신 App Store 스크린샷 재촬영 결과

2026-08-26 산출물은 캘린더 화살표 UI가 현재 앱과 달라 폐기하고, 2026-08-29에 격리된 `dutypark_demo` DB·loopback 8081 API와 실제 local demo 계정을 사용해 전체 세트를 다시 촬영했다. `DemoAppStoreCaptureUITests`는 iPhone 17 Pro Max, iOS 26.5에서 ko/en 2/2 PASS했고 결과 번들은 `/private/tmp/dutypark-appstore-capture-final3-20260829.xcresult`다. 명령·device·tested source·tree hash는 [evidence manifest](./review-evidence/2026-08-29/README.md)에 기록한다.

완료한 작업:

- ko/en 각 7개 XCTAttachment를 추출해 `docs/app-store/raw/{ko,en}/`의 14개 원본을 교체했다.
- locale별 manifest로 제출용 6개씩, 총 12개 `docs/app-store/final/{ko,en}/` 이미지를 재합성했다.
- compose/extract 검증 스크립트가 크기·alpha·manifest·중복/누락·overwrite guard를 모두 PASS했다.
- 14개 raw와 12개 final을 전수 시각 검토해 현재 원형 캘린더 화살표, 현행 문구·기능 상태, 실제 demo avatar를 확인했다. 로그인/오류 화면, 비밀값, 실제 개인 데이터는 보이지 않는다.
- 영문 Calendar·Team·D-Day는 2026-11로 이동해 한국 공휴일 라벨이 노출되지 않는다. 팀 월 컨트롤은 UI 테스트가 `2026-08`에서 `2026-11` 전환을 접근성 value로 직접 검증한다.
- 모든 raw/final은 1320x2868 opaque PNG이며 app UI는 crop·비균등 확대·재생성하지 않았다.

이 항목 자체는 **PASS**다. 다만 캡처는 Debug simulator/local demo 산출물이며 distribution signing, production entitlement 또는 최종 exported IPA를 증명하지 않는다. 제출 직전에는 업로드할 앱 build가 같은 UI revision인지 확인한다.

## 7. 최종 exported IPA, 배포 서명, 운영 APNs

exact `iPhone 13 mini` iOS 26.5에서 Release simulator build·설치·launch는 PASS했다. 실행 중 생성된 최신 임시 캡처(2절과 동일한 산출물)는 `/private/tmp/dutypark-release-latest-20260829.png`이며 장기 보존 증거·제출물로 사용하지 않는다. 최초 clean `268029a3` 배포 검증 뒤 제품 변경이 생겨, App Store Connect 제출 초안까지 포함한 clean HEAD `0f0dd64c`에서 Release device Archive와 로컬 App Store Connect IPA export를 다시 완료했다. 최신 IPA SHA-256과 검사 결과는 `ios/review-evidence/2026-08-29/`에 기록했다.

- [x] Release Archive가 운영 API base URL을 사용한다.
- [x] 2026-04-28 이후 App Store Connect 제출 요건에 맞게 최종 Archive가 iOS 26 SDK 이상으로 빌드됐는지 배포 산출물에서 확인한다.
- [x] exported IPA가 distribution signing으로 서명되고 bundle ID가 등록된 App ID와 일치한다.
- [x] `codesign` strict 검증이 통과하고 embedded provisioning profile/entitlements가 예상 target과 일치한다.
- [x] 최종 앱의 서명 entitlement와 embedded profile에서 운영 APNs 환경을 확인했다. 구체 값은 증거 JSON에 복사하지 않고 boolean 판정만 기록했다.
- [x] Associated Domains, Sign in with Apple capability, URL scheme가 배포 App ID와 일치한다.
- [x] IPA의 실제 `Info.plist`에 카메라 purpose string, version/build, 운영 API 설정이 포함된다.
- [x] clean `0f0dd64c`에서 Archive/IPA를 재생성하고 `CustomerSupport` privacy declaration 포함 여부까지 확인했다.
최신 `0f0dd64c` 산출물 로컬 확인 결과는 **PASS**다. App Store Connect 업로드·processing과 Privacy Details 저장은 12절의 제출 작업으로 통합한다.

## 8. 실기기 QA 범위

APNs, 외부 OAuth, 카메라·사진·파일 선택, 첨부 업로드, 계정 삭제를 실제 iPhone에서 smoke test하는 것은 권장한다. 그러나 Apple의 일반 제출 요건은 특정 내부 실기기 테스트 목록이나 그 증거 제출을 요구하지 않으므로 release gate에서는 제외한다. 문제가 발견되면 별도 제품 결함으로 처리하고, 파괴적 검증에는 운영 리뷰 계정이나 실제 사용자 데이터를 사용하지 않는다.

## 9. App Store Connect 제출 준비

실제 코드·공개 개인정보처리방침을 바탕으로 [App Store Connect submission draft](../docs/app-store/APP_STORE_CONNECT_SUBMISSION_DRAFT.md)를 작성했다. 이 문서는 Privacy Details 데이터 유형/목적, 외부 처리 흐름, 영문 Review Notes, 심사 계정 운용, 연령등급 질문지의 입력 초안이다. App Store Connect에 저장됐다는 증거가 아니며, 인증된 계정에서 실제 값과 validation 결과를 확인할 때까지 이 절의 외부 게이트는 닫히지 않는다.

### Privacy labels 및 정책

- [x] 저장소 초안에 앱·백엔드·SDK·외부 처리자 데이터 흐름을 재작성했다.
- [x] 저장소 초안에 이름, 이메일, user/device ID, 사진·비디오, Customer Support, 기타 사용자 콘텐츠, IP·로그, APNs 등록 정보, 문의·신고 입력, AI 전송을 수집·연결·추적 여부와 목적에 맞춰 매핑했다.
- [x] Google Gemini, Slack, Apple, Kakao, Naver의 현재 코드상 데이터 접근 범위와 배포 설정 재확인 조건을 초안에 기록했다.
- [x] `ios/Dutypark/PrivacyInfo.xcprivacy`에 실제 문의 수집에 대응하는 `CustomerSupport` 선언을 추가하고 exact-list 회귀 테스트를 보강했다.
- [x] 개인정보처리방침 URL `https://dutypark.o-r.kr/privacy`가 로그인 없이 열리고 2026-08-19 시행 정책을 표시하는 것을 2026-08-29 확인했다.

인증된 App Store Connect에서 저장할 값은 제출 초안과 12절에 통합했다. Privacy manifest만으로 포털 정보가 완성되는 것으로 보지 않는다.

### Review Notes, 계정, backend

- [x] 영문 Review Notes 초안에 로그인 절차, 주요 탭, 팀/캘린더/첨부, 신고·차단, AI 선택 동의, 계정 삭제 위치와 비동기 처리 시간·보존 예외를 적었다.
- [x] Review Notes 초안에 Apple/Kakao/Naver 외부 로그인과 core review용 password 계정 대체 경로를 설명했다.

심사용 로그인 정보는 `App Review Information`의 secure username/password 필드에만 제공한다. 실제 저장과 심사 기간 운영은 12절의 한 항목으로 통합한다.

## 10. 2026-08-24 이후 Sign in with Apple 변경사항

### 10.1 `private.icloud.com` 새 도메인

Apple의 [2026-08-24 공식 업데이트](https://developer.apple.com/news/?id=1ptvdtcm)는 2026년 후반 신규 Sign in with Apple 주소에 `private.icloud.com`이 사용될 수 있고 기존 `privaterelay.appleid.com`도 계속 동작함을 안내한다. 이는 앱·웹 계정 시스템, 이메일 검증 로직, allowlist가 두 도메인을 모두 받아들이도록 준비하라는 호환성 권고로 기록한다. 이 문서에서는 이를 별도의 App Review 필수요건으로 단정하지 않는다.

Dutypark 코드에는 웹 Sign in with Apple 경로가 존재한다.

- `src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/WebAppleOAuthController.kt`
- `src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleWebOAuthService.kt`
- `src/main/resources/application.yml`의 web client ID/redirect 설정
- 관련 정책: `src/main/resources/db/migration/v2/V2.2.35__publish_web_apple_sign_in_privacy_policy.sql`

현재 소스에는 두 도메인을 막는 allowlist가 없으므로 현재 제출 작업은 없다. 향후 운영 메일 서버에 도메인 제한을 추가하거나 Apple private relay 메일을 직접 전송할 때 두 도메인을 모두 허용한다.

공식 참고: [Communicating using the private email relay service](https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service), [Configuring your environment for Sign in with Apple](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)

### 10.2 한국 개발자의 Services ID S2S notification endpoint

Apple의 [한국 개발자 대상 공식 안내](https://developer.apple.com/news/?id=j9zukcr6)에 따르면 2026-01-01부터 한국에 기반을 둔 개발자가 웹사이트를 앱과 연결하는 새 Services ID를 등록하거나 기존 Services ID를 업데이트할 때 server-to-server notification endpoint를 제공해야 한다. Apple이 보낼 수 있는 이벤트에는 다음이 포함된다.

- 이메일 전달 환경설정 변경
- 앱에서의 계정 삭제
- Apple 계정 영구 삭제

저장소 운영 구성상 웹 Sign in with Apple은 활성이다. 운영 client ID와 production callback은 `frontend/.env.production:4-5`에 있고, 웹 Apple exchange 경로는 `src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/WebAppleOAuthController.kt:17-34` 및 `src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleWebOAuthService.kt:11-40`에서 확인된다. 따라서 웹 SIWA 사용 여부 자체는 선택적 확인 항목이 아니다.

현재 저장소에는 웹 Apple exchange endpoint는 있지만 Apple S2S notification endpoint/notification JWT 처리 경로는 확인되지 않는다. 별도 인프라에 구현되어 있을 수 있으므로 소스 부재만으로 미구현이라고 단정하지 않는다. Apple의 [S2S notification 구성 안내](https://developer.apple.com/help/account/capabilities/enabling-server-to-server-notifications/)처럼 이 endpoint를 등록하는 위치는 Services ID 자체가 아니라, 웹사이트와 연결된 **primary App ID의 Sign in with Apple 구성**이다.

이 요구는 한국 소재 개발자가 **새 Services ID를 등록하거나 기존 Services ID를 업데이트해 웹사이트를 앱과 연결하는 Developer Account 작업을 할 때** 적용된다. 현재 iOS 빌드 제출 자체에는 Services ID 등록·업데이트가 포함되지 않으므로 S2S 구현을 이번 제출의 무조건적인 gate로 두지 않는다. 나중에 해당 Developer Account 작업을 수행한다면 그 시점에 primary App ID에 endpoint를 등록하고 notification JWT 검증·retry·replay/idempotency·개인정보 최소화를 함께 구현한다. 실제 URL·secret은 저장소 문서에 기록하지 않는다.

## 11. 한국 연령 등급 판단

Apple의 [연령 등급 값 및 정의](https://developer.apple.com/kr/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)에 따르면 연령 등급은 필수 App Store Connect 정보이고, 질문지의 콘텐츠 유형·앱 내 제어·기능 존재·빈도 답변으로 전 세계 및 지역별 등급이 계산된다. “등급 없음”은 App Store에 게시할 수 없다.

### Dutypark의 잠정 자기판정

현재 확인된 기능만 기준으로는 다음 조건에서 **Apple global 4+ / 대한민국 ‘전체(All)’ 가능성**이 있다.

- 일반 일정·근무표·Todo·팀 공유가 주 기능
- 폭력, 성적 내용/노출, 도박/랜덤박스, 주류·담배·약물, 의료·치료 정보, 욕설·성인 테마가 의도된 콘텐츠로 제공되지 않음
- 사용자 생성 일정·Todo·프로필·첨부의 주된 공유는 팀/친구 범위이고 social feed/discovery는 없지만, `PUBLIC` 일정·D-Day는 비로그인 접근 및 iOS ShareLink로 공개·재공유가 가능함
- 사용자 간 직접 메시지·채팅·공개 게시판이 없음

이는 최종 등급이 아니다. App Store Connect 질문지에 다음을 실제 기능 기준으로 답하고 결과를 기록한다.

| 질문 영역 | Dutypark 확인 포인트 | 판정 상태 |
|---|---|---|
| User-Generated Content | 타인에게 공유되는 일정·Todo·프로필·사진·파일의 범위·빈도와 `PUBLIC` 일정·D-Day의 비로그인 접근·ShareLink 재공유 | **질문지 최종 입력 후 기입** |
| Messaging and Chat | 직접/그룹 메시지, 공개 게시, 문의 답변이 사용자 간 통신인지 | **기능 확인 후 기입** |
| Social Media | 소셜 피드·검색·추천·재배포로 많은 사용자에게 UGC가 보이는지 | **해당 시 Social Media 및 연령 제한 검토** |
| Medical or Wellness | 근무표를 건강/치료/진단으로 표현하는지, 실제 건강·웰니스 콘텐츠가 있는지 | **없음이면 없음으로 정확히 답변** |
| Mature/Profanity/Violence/Gambling | 콘텐츠 필터 목록 존재가 아니라 앱에서 실제 노출되는 빈도 기준 | **실제 fixture·운영 콘텐츠 대조** |
| Advertising / parental controls / age assurance | 광고·나이 확인·유해 콘텐츠 차단 기능 존재 여부 | **질문지 최종 입력 후 기입** |

코드 기준 잠정 답변(User-Generated Content 있음, Messaging/Chat 없음, Social Media 없음, Productivity 주 카테고리 등)은 [App Store Connect submission draft](../docs/app-store/APP_STORE_CONNECT_SUBMISSION_DRAFT.md)에 정리했다. 이는 App Store Connect의 실제 질문 문구에 답하고 계산된 등급을 받은 결과가 아니다.

## 12. 실제 제출에 남은 작업

- [ ] clean `0f0dd64c` IPA와 준비된 ko/en 스크린샷을 등록하고 build processing 완료를 확인한다.
- [ ] 초안대로 App Privacy Details와 개인정보처리방침 URL을 저장하고 manifest validation을 확인한다.
- [ ] Review Notes와 secure reviewer username/password를 저장하고 심사 기간에 계정·core backend를 유지한다.
- [ ] 현재 App Store Connect 연령등급 질문지에 실제 기능대로 답하고 계산된 등급을 저장한다.

위 네 항목은 인증된 App Store Connect에서만 완료할 수 있다. 실기기 전수 E2E, 모든 내부 DB row 확인, raw 테스트 artifact 장기 보관, 고정 문의·신고 보존일 확정, 조건이 발생하지 않은 Services ID S2S 구현은 이번 제출 체크리스트에 포함하지 않는다.
