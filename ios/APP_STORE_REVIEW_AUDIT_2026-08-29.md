# Dutypark iOS App Store 심사 증분·최종 게이트 보고서

- 기준일: 2026-08-29 (KST)
- 판정: **HOLD — 제출하지 않음**
- 코드 기준: committed HEAD `c01f1174` 위의 현재 App Store Connect 제출 초안 작업 트리. 스크린샷 개선은 `268029a3`, 배포 IPA 검증 기록은 `e7b12b93`, Customer Support privacy declaration은 `f03d53a2`, Calendar 시간 표시는 `c01f1174`에 포함된다. 최종 제출 전에는 커밋 SHA가 고정된 동일 소스를 다시 검증해야 한다.
- 목적: [2026-08-28 보고서](./APP_STORE_REVIEW_AUDIT_2026-08-28.md)의 반복이 아닌, 그 이후 변경분과 제출 직전의 미검증 게이트를 기록한다.
- 비밀값: 비밀번호, private key, client secret, webhook token, 실제 S2S URL은 이 문서에 기록하지 않는다. 심사용 계정은 App Store Connect의 `App Review Information → Sign-in required → Username / Password` 필드에서만 제공한다.

## 1. 최종 판정

코드 변경에 대한 자동 검증은 PASS했지만, 아래 외부·실기기·배포 산출물 게이트가 닫히지 않았고 사업자 개인정보 보존 결정도 남아 있으므로 제출 판정은 **HOLD**다.

| 제출 게이트 | 현재 판단 | 제출 전 조건 |
|---|---|---|
| Slack 개인정보 제거 | 수정 반영됨 | Slack privacy focused 54 PASS. 전체 Release/실제 webhook 배포 확인은 별도 게이트 |
| UGC 텍스트 필터 | 클라이언트·일부 서버 보강 반영됨 | backend/iOS 관련 focused·full 검증 PASS. 웹 정규화·private D-Day 예외는 반영됐고 cold-start/fetch fail-open, 모든 공개/공유 쓰기 경로·첨부·신고 흐름은 별도 게이트 |
| 문의·신고 탈퇴 후 보존 | 사업자 결정 HOLD | exact retention/purge 기간, snapshot·식별자 최소화, legal hold 범위·종료 조건 및 사용자 고지·Privacy declarations 일치 확정 |
| 비동기 계정 삭제 완료 확인 | backend·web·iOS 구현 및 자동 테스트 PASS | 보통 5분 이내 ETA, 로그아웃 후 receipt 기반 상태 조회, 실제 `COMPLETED` confirmation, `FAILED` 지원 경로를 구현. disposable 운영 유사 계정 E2E는 별도 게이트 |
| App Store 스크린샷 | 최신 ko/en 세트 재촬영·재합성·시각 검토 PASS | 제출할 build와 이미지 source가 같음을 최종 업로드 전에 한 번 더 확인 |
| 배포 IPA | clean `268029a3` Archive/export 및 로컬 검사 PASS, 이후 제품 변경으로 재생성 필요 | 최종 제출 commit에서 Archive/export·manifest·서명을 다시 확인하고 App Store Connect processing 확인 |
| 실제 iPhone E2E | 미실행 또는 일부 미검증 | APNs, OAuth, 카메라, 파일 picker, 파괴적 흐름 완료 |
| App Store Connect | 저장소 입력 초안 작성; 인증된 포털 입력 대기 | privacy labels, Review Notes, secure demo account, questionnaire, backend 준비 |
| 한국 Apple Services ID / S2S | 저장소 운영 구성상 웹 Sign in with Apple 활성; Apple 직접 적용 여부와 외부 S2S 등록·처리 미확인 | Developer Account의 한국 소재·Services ID 등록/변경 시점·연결된 primary App ID를 확인하고 S2S endpoint, notification JWT, retry/replay/idempotency 처리를 검증하는 필수 미완료 게이트 |
| 연령 등급 | 최종 questionnaire 미작성 | App Store Connect 질문에 실제 기능 기준으로 답변 |

Apple은 앱 완성도, 개인정보처리방침, 계정 삭제, UGC, 메타데이터를 실제 빌드·서버 동작과 함께 심사한다. 그러므로 시뮬레이터의 일부 성공이나 코드에 기능이 존재한다는 사실만으로 승인 가능으로 올리지 않는다.

Apple routine review의 경계도 구분한다. Apple이 내부 DB를 직접 조회·감사한다고 전제하지 않으며, 이 보고서의 제출 기준은 배포 환경에서 관찰 가능한 live-backend flow와 앱·App Store Connect Privacy Details·개인정보처리방침의 선언이 서로 일치하는지 확인하는 것이다. 내부 DB/SQL·xcresult는 Dutypark의 traceability와 release evidence일 뿐 Apple의 직접 DB audit 결과로 표현하지 않는다.

## 2. 2026-08-29 검증 결과

이번 변경분에 대해 자동 검증은 다음과 같이 완료됐다. 아래 PASS는 실행한 테스트와 산출물에만 적용하며, 외부 서비스·실기기·배포 심사 게이트를 대신하지 않는다.

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
| Evidence manifest | 작성됨 | [2026-08-29 evidence manifest](./review-evidence/2026-08-29/README.md)에 fresh backend/web/iOS unit 재실행의 명령·tested SHA·결과와 기존 UI xcresult/capture provenance를 기록. 전체 bundle/log의 장기 artifact 저장은 HOLD |

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
- Slack을 운영 채널로 계속 사용한다면 개인정보처리방침의 제3자 처리자, 목적, 접근자, 보존·삭제 정책과 App Store Connect Privacy Details를 실제 payload에 맞춰 갱신한다. enum-only 변경의 focused test는 PASS했지만, 배포 IPA에 포함되는지와 실제 운영 webhook 설정은 별도 제출 게이트로 남아 있다.

### 4.2 UGC 텍스트 필터 보강

Apple [App Review Guidelines 1.2](https://developer.apple.com/app-store/review/guidelines/)는 UGC 서비스에 게시 전 부적절한 내용 필터링 수단, 신고·신속한 대응, 사용자 차단, 공개 연락처를 요구한다. 현재 작업 트리의 증분은 다음과 같다.

| 변경 | 근거 경로 | 의도 | 검증 |
|---|---|---|---|
| 캐시가 없거나 오프라인이어도 iOS 번들 사본 또는 emergency fallback을 사용 | `ios/Dutypark/Core/ContentFilter/ContentFilterStore.swift`, `ios/Dutypark/Core/ContentFilter/banned-words.json` | iOS cold/offline launch에서 fail-open 되지 않음 | **관련 iOS focused/unit 검증 PASS** |
| 캘린더 입력을 client filter로 검사하고, D-Day는 공개일 때만 검사(private는 허용) | `ios/Dutypark/Features/Calendar/CalendarViewModel.swift` | 사용자 입력 직전 안내와 오류 haptic; private D-Day는 저장 허용 | **관련 iOS focused/unit 검증 PASS** |
| Todo, 팀, 프로필/회원가입 입력을 client filter로 검사 | `ios/Dutypark/Features/Todo/TodoViewModel.swift`; `ios/Dutypark/Features/Team/TeamViewModel.swift`; `ios/Dutypark/Features/Settings/SettingsViewModel.swift`; `ios/Dutypark/Features/Auth/SsoSignupView.swift` | 주요 공개/공유 문자열의 일관된 UX | **관련 iOS focused/unit 검증 PASS** |
| API가 동일 정규화·substring matching을 제공하고 공개 D-Day 및 근무유형/기본 근무유형 mutation을 서버에서 검증 | `src/main/kotlin/com/tistory/shanepark/dutypark/publiccontent/service/PublicContentService.kt`; `src/main/kotlin/com/tistory/shanepark/dutypark/member/service/DDayService.kt`; `src/main/kotlin/com/tistory/shanepark/dutypark/duty/service/DutyTypeService.kt`; `src/main/kotlin/com/tistory/shanepark/dutypark/team/service/TeamService.kt` | client preflight 우회 방지; private D-Day는 서버 검증 대상에서 제외 | **관련 backend focused/full 검증 PASS** |

정규화 계약은 backend와 iOS에서 code point를 기준으로 동일하게 맞춰져 있다. 입력과 목록 항목 모두 NFKC 정규화와 lowercase를 거친 뒤 Unicode letter 및 decimal digit(`Nd`)만 남기고 substring으로 비교한다. iOS는 Unicode scalar general category의 `L*`와 decimal number를 사용하고, backend는 code point 기반 letter/digit 판정을 사용한다. D-Day는 공개 항목만 이 서버·클라이언트 검사를 적용하며 private D-Day는 허용한다. 근무유형과 팀 기본 근무유형은 팀에 공유되는 이름이므로 별도의 서버 mutation 검증 대상이다.

웹도 NFKC·lowercase·Unicode letter 및 decimal digit(`Nd`) 정규화와 private D-Day 예외를 반영 완료했다. 남은 웹 잔여 위험은 cold start에서 캐시가 없거나 fetch가 실패하면 빈 목록으로 남아 client check가 fail-open되는 점이다. 또한 서버 enforcement는 공개 D-Day와 근무유형/기본 근무유형 경계에 한정되어 Schedule/Todo의 모든 서버 mutation을 덮는다고 볼 수 없다. 웹 fail-open 해소 또는 모든 공유 mutation의 서버 강제는 UGC 제출 게이트의 독립 잔여 위험이다.

세 런타임은 같은 NFKC·Unicode letter/decimal digit 규칙을 구현하지만 contextual lowercase가 그리스어 final sigma 같은 문자에서 다른 결과를 낼 수 있다. 현재 46개 영어·한국어 목록에는 즉시 영향이 없지만, 새 script를 추가할 때 cross-runtime fixture/parity test를 추가하는 것을 잔여 게이트로 남긴다.

자동 검증으로 확인된 현재 범위와 남은 UGC 게이트:

- 서버 `validateContent` 호출은 현재 D-Day, duty type, team default duty에서 확인되었고, 관련 backend focused/full 검증은 PASS했다. 다만 `ScheduleService`와 `TodoService`의 서버 생성·수정 경로가 공개/친구/팀 공유 범위에 따라 필터를 우회하지 않는지는 아직 별도 코드·E2E 게이트로 남아 있다. 따라서 UGC 변경의 자동 회귀는 PASS로 기록하되 서버 mutation 전체 보호 완료로 확대 해석하지 않는다.
- backend JSON, iOS bundled JSON, `ContentFilterStore`의 `emergencyWords`는 중복된 목록 소스다. backend 기동 검증은 backend JSON 자체만 검사하며, 세 소스 사이의 자동 동기화·생성·동일성 검증은 없다. 수동 목록 변경이 한 소스에만 반영될 수 있으므로 이를 residual risk로 유지한다.
- 텍스트 필터는 사진·동영상·파일의 음란·혐오 이미지를 자동 판정하지 않는다. 첨부가 타인에게 공개되는 기능이면 신고/차단/운영자 삭제와 신속 대응을 실제로 검증한다.
- 신고 대상이 삭제 또는 탈퇴한 계정이어도 운영자가 필요한 증거를 확인할 수 있는지, 동시에 Apple 계정 삭제 요구와 보존정책이 일치하는지 확인한다.
- 필터 단어 목록은 표현 차단의 전부가 아니다. 폭력 위협, 괴롭힘, 개인정보 노출, 반복 악성 행위에 대한 운영 정책과 조치 흐름도 Review Notes/정책에서 설명한다.

## 5. 사용자·사업자가 반드시 결정할 개인정보 보존 정책

Apple은 계정 삭제 시 계정과 관련된 데이터 및 UGC를 원칙적으로 삭제하도록 요구하고, 법적 보존 의무가 있는 경우에만 예외를 인정한다. [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)은 보존되는 정보를 사용자에게 설명하고, 단순 비활성화나 고객센터 연락만으로 대체하지 않도록 한다.

현재 `src/main/resources/db/migration/v2/V2.2.44__publish_ugc_privacy_policy.sql`은 다음을 명시한다.

- 문의 기록은 계정 삭제 후에도 보존
- 신고 기록, 신고자·피신고자 이름 snapshot, 신고 대상 콘텐츠 snapshot도 보존
- 고정된 자동 삭제 주기 없음
- 목적 달성 후 삭제 또는 익명화한다는 원칙만 존재

이 문구는 사업자와 사용자에게 다음처럼 확정되어야 한다. 빈칸을 결정하지 않은 채 제출하지 않는다.

| 결정 항목 | 반드시 정할 내용 | 현재 상태 |
|---|---|---|
| 문의 보존기간 | 계정 삭제/문의 종료/마지막 처리 중 어느 시점부터 며칠 또는 몇 개월 보존할지 | **사업자 결정 필요 — `최종 검증 후 기입`** |
| 문의 익명화 | 이름·이메일·IP·본문·첨부·답변 중 어느 필드를 언제 익명화할지 | **사업자 결정 필요 — `최종 검증 후 기입`** |
| 신고 보존기간 | 신고 접수·처리·이의제기·법적 hold별 최대기간 | **사업자 결정 필요 — `최종 검증 후 기입`** |
| 신고 snapshot | 원문 전체가 필요한지, 최소 excerpt/hash/분류만 남길지 | **사업자 결정 필요 — `최종 검증 후 기입`** |
| 신고 당사자 식별자 | 이름 snapshot을 유지할지, 즉시 익명 ID로 바꿀지 | **사업자 결정 필요 — `최종 검증 후 기입`** |
| 법적 보존 예외 | 적용 법령/분쟁·안전 사유, 보존 범위와 종료 조건 | **법무·사업자 확인 필요 — `최종 검증 후 기입`** |
| 관리자 접근 | 운영자 중 누가 어느 기간 동안 어떤 필드에 접근할지 | **사업자 결정 필요 — `최종 검증 후 기입`** |
| 계정 삭제 감사 데이터 | deletion job의 root/target ID, 상태, 오류 코드, timestamp와 실패 시 남을 수 있는 provider credential의 보존·파기 기한 | **법무·사업자·운영 결정 필요 — `최종 검증 후 기입`** |
| 탈퇴 UI 고지 | 삭제되는 데이터, 공동 팀 데이터, 남는 신고/문의 기록, 익명화 시점, 비동기 처리 ETA·상태/완료 표시·실패/재시도 경로 | **UI·정책 동시 확정 필요 — `최종 검증 후 기입`** |

탈퇴 화면에는 최소한 다음을 사용자에게 직접 보여줘야 한다.

1. 삭제 요청으로 삭제를 시작하는 계정·일정·Todo·첨부·OAuth 연결과 삭제 완료 예상시간(ETA), 상태/완료 확인 방법 및 실패 시 안내·재시도 경로
2. 공동 팀 데이터처럼 권한 이관 또는 다른 사용자의 기능을 위해 처리되는 항목
3. 법적 보존 또는 안전·분쟁 대응으로 남을 수 있는 문의·신고 항목과 정확한 기간
4. 남는 항목의 익명화 방식과 관리자 접근 범위
5. Sign in with Apple 연결 해제 및 토큰 철회 결과

사업자가 보존기간을 결정하기 전까지는 계정 삭제와 개인정보 심사를 PASS로 기록하지 않는다.

### Apple 최소 요건과 Dutypark 내부 게이트의 구분

Apple의 최소 요건은 앱 안에서 계정 삭제를 시작할 수 있고, 삭제 범위와 법적 보존 예외를 설명하며, 계정과 관련 데이터를 실제로 삭제하는 경로를 제공하는 것이다. Apple FAQ는 삭제가 즉시·자동일 필요는 없다고 설명하므로 서버의 비동기 처리 자체를 부적합으로 단정하지 않는다. 다만 비동기 처리라면 사용자에게 예상 소요시간을 알리고 삭제 완료 후 confirmation을 제공해야 한다.

현재 작업 트리는 이 제품 수준 누락을 보완했다. 클라이언트가 삭제 요청 전에 32-byte CSPRNG receipt token을 만들고 저장하며 서버는 원문 대신 SHA-256만 보관한다. 로그인 세션을 제거한 뒤에도 web과 iOS가 5초 간격으로 공개 status API를 조회하여 `PROCESSING`, 실제 worker의 `COMPLETED`, 최종 `FAILED`를 구분한다. UI에는 정상 상황에서 **보통 5분 이내**라는 ETA를 표시하고, 실제 완료 후에만 완료 confirmation과 success feedback을 제공한다. 실패·만료·알 수 없는 응답은 완료로 오인하지 않고 `/support` 안내를 제공한다. 요청이 서버에 접수됐는지 불명확한 network/5xx/응답 파싱 실패에도 요청 전 receipt를 유지하고 status 흐름으로 전환하며, ETA 전의 일시적 404는 계속 polling한다. receipt는 로컬 계정 ID에 묶어 다른 로그인 계정의 삭제 요청에 재사용하거나 덮어쓰지 않는다. terminal receipt는 완료 또는 최종 실패 후 30일 동안 상태 확인에만 사용되며, raw token은 URL·query·로그·analytics에 넣지 않는다. worker의 상태 전이는 claim별 lease token으로 보호한다.

현재 구현으로 해소된 제품 수준 범위는 삭제 요청의 ETA 안내, 로그아웃 뒤 receipt 기반 상태 조회, `COMPLETED` 완료 confirmation, `FAILED` 지원 경로다. 이번 추가 고지는 5분 ETA가 삭제 대상으로 안내한 계정 데이터·파일에 적용되고 문의·신고 기록에는 별도 보존·삭제 기준이 적용될 수 있음을 탈퇴 전·후 화면에서 명시하며, 현재 공개 개인정보처리방침으로 연결한다. 이 범위는 backend·web·iOS 자동 테스트로 확인됐지만, live production backend에서 disposable 계정으로 처음부터 끝까지 관찰하는 검증과 App Store Connect Privacy Details·개인정보처리방침·실제 UI 고지의 일치성은 별도 게이트다. receipt의 30일 상태 확인 만료는 문의·신고·계정 삭제 감사 데이터의 보존기간을 정한 것이 아니다.

exact retention/purge 일정, 문의·신고 snapshot과 식별자의 최소화, deletion audit record 및 실패 시 provider credential의 파기 시점, legal hold의 적용 범위·종료 조건은 이번 구현이나 자동 테스트로 결정되지 않는다. 이 항목들은 사업자·법무·운영 결정과 사용자/Privacy declarations 반영이 끝날 때까지 **HOLD**로 남긴다.

Dutypark의 내부 게이트는 이 최소 요건보다 보수적이다. 위 흐름의 backend·web·iOS 자동 테스트는 PASS했지만, disposable 계정으로 비동기 완료까지 확인한 뒤 세션·token·OAuth 연결·UGC·첨부 및 보존 예외가 정책과 일치하는지는 아직 실제 서버에서 검증하지 않았다. 상태 API에 앱 자체 rate limiter는 없으므로, 256-bit status-only token 외에도 운영 edge/IP rate limit이 적용되는지 배포 환경에서 확인한다. 이 내부 E2E와 사업자 보존 결정이 끝나지 않았으므로 제출 판정은 계속 HOLD다.

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

exact `iPhone 13 mini` iOS 26.5에서 Release simulator build·설치·launch는 PASS했다. 실행 중 생성된 최신 임시 캡처(2절과 동일한 산출물)는 `/private/tmp/dutypark-release-latest-20260829.png`이며 장기 보존 증거·제출물로 사용하지 않는다. clean HEAD `268029a3`에서 별도 Release device Archive와 로컬 App Store Connect IPA export도 성공했고, IPA SHA-256과 검사 결과는 `ios/review-evidence/2026-08-29/`에 기록했다. 다만 이 산출물 뒤 `f03d53a2` privacy manifest와 `c01f1174` 앱 변경이 추가됐으므로, 기존 IPA는 서명·export 절차 증거이지 현재 최종 제출 바이너리가 아니다.

- [x] Release Archive가 운영 API base URL을 사용한다.
- [x] 2026-04-28 이후 App Store Connect 제출 요건에 맞게 최종 Archive가 iOS 26 SDK 이상으로 빌드됐는지 배포 산출물에서 확인한다.
- [x] exported IPA가 distribution signing으로 서명되고 bundle ID가 등록된 App ID와 일치한다.
- [x] `codesign` strict 검증이 통과하고 embedded provisioning profile/entitlements가 예상 target과 일치한다.
- [x] 최종 앱의 서명 entitlement와 embedded profile에서 운영 APNs 환경을 확인했다. 구체 값은 증거 JSON에 복사하지 않고 boolean 판정만 기록했다.
- [x] Associated Domains, Sign in with Apple capability, URL scheme가 배포 App ID와 일치한다.
- [x] IPA의 실제 `Info.plist`에 카메라 purpose string, version/build, 운영 API 설정이 포함된다.
- [ ] 최종 제출 commit에서 Archive/IPA를 재생성하고 `CustomerSupport` privacy declaration 포함 여부까지 다시 확인한다.
- [ ] TestFlight/App Store Connect processing, export validation, 설치 가능한 빌드 상태를 확인한다.
- [ ] 배포 IPA의 개인정보 manifest와 포함 SDK manifest가 App Store Connect Privacy Details와 일치한다.

기존 `268029a3` 산출물 로컬 확인 결과: **PASS**. 현재 코드의 최종 산출물은 재생성 전이므로 **HOLD**이며, 이후에도 App Store Connect 업로드·processing과 Privacy Details 실계정 대조는 외부 확인 항목으로 남는다.

## 8. 실기기 필수 E2E 및 실제 파괴적 흐름

Apple은 시뮬레이터 성공을 실기기·외부 공급자·배포 환경 검증으로 간주하지 않는다. 운영 계정이 아닌 disposable 계정과 테스트 팀을 사용하고, 파괴적 동작의 결과를 되돌릴 수 있게 준비한다.

### 실기기·공급자 흐름

- [ ] APNs 권한 허용/거부, 앱 설정 토글, cold launch 후 상태 유지, 실제 production 알림 수신
- [ ] 백그라운드·잠금화면에서 일정·문의·팀 등 민감한 본문이 노출되지 않음
- [ ] APNs token 등록·갱신·로그아웃·알림 해제 시 서버 제거
- [ ] Apple native 로그인/가입/재인증, 취소·실패·재시도
- [ ] Kakao/Naver OAuth callback, callback 취소·잘못된 state·외부 앱 미설치 처리
- [ ] 카메라로 프로필 사진 촬영 및 권한 거부 fallback
- [ ] PhotosPicker, Files picker, 고해상도 사진·큰 파일 선택, 업로드·미리보기·공유·다운로드·삭제
- [ ] 로그아웃/앱 재실행 후 첨부 임시파일이 남지 않음

### 실제 파괴적 흐름

- [ ] disposable 계정으로 D-Day·일정·Todo 생성/수정/삭제와 서버 결과 확인
- [ ] disposable 팀에서 멤버 제거, 친구 차단·해제, 콘텐츠 신고·철회, 관리자 삭제/정지 흐름 확인
- [ ] 계정 탈퇴를 끝까지 실행하고 비동기 완료·로그인 차단·세션/token/OAuth credential 정리 확인
- [ ] 탈퇴 후 삭제 대상과 보존 대상으로 결정한 문의·신고 records를 직접 조회해 정책과 일치하는지 확인
- [ ] 공동 팀 데이터·권한 이관·공유 첨부가 고지된 동작과 일치하는지 확인

각 항목 결과: **`최종 검증 후 기입`**. 운영 리뷰 계정이나 실제 사용자 데이터로 파괴적 테스트를 하지 않는다.

## 9. App Store Connect 제출 준비

실제 코드·공개 개인정보처리방침을 바탕으로 [App Store Connect submission draft](../docs/app-store/APP_STORE_CONNECT_SUBMISSION_DRAFT.md)를 작성했다. 이 문서는 Privacy Details 데이터 유형/목적, 외부 처리 흐름, 영문 Review Notes, 심사 계정 운용, 연령등급 질문지의 입력 초안이다. App Store Connect에 저장됐다는 증거가 아니며, 인증된 계정에서 실제 값과 validation 결과를 확인할 때까지 이 절의 외부 게이트는 닫히지 않는다.

### Privacy labels 및 정책

- [x] 저장소 초안에 앱·백엔드·SDK·외부 처리자 데이터 흐름을 재작성했다.
- [x] 저장소 초안에 이름, 이메일, user/device ID, 사진·비디오, Customer Support, 기타 사용자 콘텐츠, IP·로그, APNs 등록 정보, 문의·신고 입력, AI 전송을 수집·연결·추적 여부와 목적에 맞춰 매핑했다.
- [x] Google Gemini, Slack, Apple, Kakao, Naver의 현재 코드상 데이터 접근 범위와 배포 설정 재확인 조건을 초안에 기록했다.
- [x] `ios/Dutypark/PrivacyInfo.xcprivacy`에 실제 문의 수집에 대응하는 `CustomerSupport` 선언을 추가하고 exact-list 회귀 테스트를 보강했다.
- [x] 개인정보처리방침 URL `https://dutypark.o-r.kr/privacy`가 로그인 없이 열리고 2026-08-19 시행 정책을 표시하는 것을 2026-08-29 확인했다.
- [ ] 인증된 App Store Connect에서 초안대로 Privacy Details를 저장하고 manifest·포털 validation 결과를 대조한다. Privacy manifest만으로 제출 정보가 완성되는 것으로 보지 않는다.
- [ ] 제출 직전 외부 환경에서 정책 URL 가용성과 앱 내부 접근 경로를 다시 확인한다.
- [ ] 계정 삭제·동의 철회·AI 선택 동의·외부 제공·보존기간이 최신 UI와 정책에서 일치한다.

### Review Notes, 계정, backend

- [ ] 심사용 계정은 App Store Connect 보안 필드에만 입력하고 이 문서·소스·스크린샷에 비밀번호를 남기지 않는다.
- [x] 영문 Review Notes 초안에 로그인 절차, 주요 탭, 팀/캘린더/첨부, 신고·차단, AI 선택 동의, 계정 삭제 위치와 비동기 처리 시간·보존 예외를 적었다.
- [ ] 심사용 로그인 정보는 App Store Connect `App Review Information` → `Sign-in required` → `Username` / `Password` 공식 필드에만 제공하고, Review Notes나 문서에는 비밀번호를 복사하지 않는다.
- [x] Review Notes 초안에 Apple/Kakao/Naver 외부 로그인과 core review용 password 계정 대체 경로를 설명했다.
- [ ] 인증된 App Store Connect에서 Review Notes와 secure reviewer account 필드를 저장하고 최종 문구를 확인한다.
- [ ] 운영 backend, API, 정책 URL, 파일 저장소, OAuth callback, Apple token exchange, APNs production이 심사 기간 내 동작한다.
- [ ] 심사 계정의 기존 데이터와 파괴적 테스트 데이터가 섞이지 않도록 disposable/읽기 전용 fixture를 분리한다.

## 10. 2026-08-24 이후 Sign in with Apple 변경사항

### 10.1 `private.icloud.com` 새 도메인

Apple의 [2026-08-24 공식 업데이트](https://developer.apple.com/news/?id=1ptvdtcm)는 2026년 후반 신규 Sign in with Apple 주소에 `private.icloud.com`이 사용될 수 있고 기존 `privaterelay.appleid.com`도 계속 동작함을 안내한다. 이는 앱·웹 계정 시스템, 이메일 검증 로직, allowlist가 두 도메인을 모두 받아들이도록 준비하라는 호환성 권고로 기록한다. 이 문서에서는 이를 별도의 App Review 필수요건으로 단정하지 않는다.

Dutypark 코드에는 웹 Sign in with Apple 경로가 존재한다.

- `src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/WebAppleOAuthController.kt`
- `src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleWebOAuthService.kt`
- `src/main/resources/application.yml`의 web client ID/redirect 설정
- 관련 정책: `src/main/resources/db/migration/v2/V2.2.35__publish_web_apple_sign_in_privacy_policy.sql`

현재 소스에서 `privaterelay.appleid.com` 또는 `private.icloud.com`을 명시한 allowlist는 발견되지 않았다. 일반 이메일 형식 검증만으로 충분한지, 운영 메일 서버의 domain filter/suppression/forwarding 규칙이 새 도메인을 막지 않는지는 외부 설정 확인이 필요하다.

- 웹 또는 이메일 relay를 운영하면 두 도메인 수용 여부(호환성 권고): **`최종 검증 후 기입`**
- 실제 계정 변경·메일 전달 테스트 결과: **`최종 검증 후 기입`**
- Apple relay를 사용하지 않는다면 그 사실과 `requestedScopes`/정책의 일치 여부를 Review Notes에 기록한다.

공식 참고: [Communicating using the private email relay service](https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service), [Configuring your environment for Sign in with Apple](https://developer.apple.com/documentation/signinwithapple/configuring-your-environment-for-sign-in-with-apple)

### 10.2 한국 개발자의 Services ID S2S notification endpoint

Apple의 [한국 개발자 대상 공식 안내](https://developer.apple.com/news/?id=j9zukcr6)에 따르면 2026-01-01부터 한국에 기반을 둔 개발자가 웹사이트를 앱과 연결하는 새 Services ID를 등록하거나 기존 Services ID를 업데이트할 때 server-to-server notification endpoint를 제공해야 한다. Apple이 보낼 수 있는 이벤트에는 다음이 포함된다.

- 이메일 전달 환경설정 변경
- 앱에서의 계정 삭제
- Apple 계정 영구 삭제

저장소 운영 구성상 웹 Sign in with Apple은 활성이다. 운영 client ID와 production callback은 `frontend/.env.production:4-5`에 있고, 웹 Apple exchange 경로는 `src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/WebAppleOAuthController.kt:17-34` 및 `src/main/kotlin/com/tistory/shanepark/dutypark/security/oauth/apple/AppleWebOAuthService.kt:11-40`에서 확인된다. 따라서 웹 SIWA 사용 여부 자체는 선택적 확인 항목이 아니다.

현재 저장소에는 웹 Apple exchange endpoint는 있지만 Apple S2S notification endpoint/notification JWT 처리 경로는 확인되지 않는다. 별도 인프라에 구현되어 있을 수 있으므로 소스 부재만으로 미구현이라고 단정하지 않는다. Apple의 [S2S notification 구성 안내](https://developer.apple.com/help/account/capabilities/enabling-server-to-server-notifications/)처럼 이 endpoint를 등록하는 위치는 Services ID 자체가 아니라, 웹사이트와 연결된 **primary App ID의 Sign in with Apple 구성**이다.

Apple 직접 요구사항의 적용 여부는 별도로 판정한다. 2026-01-01 이후 한국에 기반을 둔 개발자가 새 Services ID를 등록하거나 기존 Services ID를 업데이트한 경우에 S2S endpoint 제공 요구가 적용된다. Developer Account에서 한국 소재와 Services ID 등록·변경 시점을 아직 확인하지 않았으므로 Apple 직접 강제 여부는 미판정이다. 그러나 저장소 운영 구성상 활성인 web SIWA에 대한 Dutypark 내부 release gate로서 아래 endpoint·JWT·retry/replay/idempotency 검증은 조건과 관계없이 필수 미완료로 유지한다.

필수 미완료 게이트 (Dutypark 내부 release gate):

- [ ] Developer Account에서 개발자/법인 소재지가 한국인지, web Services ID가 어느 primary App ID에 연결됐는지, Services ID 최초 등록·최근 업데이트 시점을 확인한다. 실제 URL·secret은 이 문서에 기록하지 않는다.
- [ ] Developer Account에서 연결된 primary App ID의 Sign in with Apple 구성에 S2S endpoint가 등록되어 있는지 확인한다. 실제 URL·secret은 이 문서에 기록하지 않는다.
- [ ] endpoint가 Apple notification JWT를 검증하고 email forwarding 변경, 앱 내 계정 삭제, Apple 계정 영구 삭제를 idempotently 처리하는지 확인
- [ ] 통지를 받은 후 계정 연결·refresh credential·개인정보 삭제/비활성화가 즉시 반영되는지 확인
- [ ] endpoint HTTP status, retry, replay/idempotency, 로그의 개인정보 최소화 확인

S2S 확인 결과: **`최종 검증 후 기입`**.

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

Apple 정의상 단순 UGC capability는 대한민국 ‘전체’ 표에도 포함될 수 있지만, 소셜 피드나 다수에게 콘텐츠를 확산시키는 기능은 `Social Media`로 별도 판단한다. Social Media를 13세 미만에게 제한하려면 Apple은 최소한 Declared Age Range API로 연령대를 확인하고 연령에 맞는 UGC만 제공하도록 안내한다. 해당 기능을 제공하지 않으면서 소셜 미디어로 분류될 수 있는 UI가 있는지 확인한다.

### 대한민국 지역 변경

- [2026-08-12 한국 연령 등급 업데이트](https://developer.apple.com/kr/news/?id=oj3r9pvw)에 따르면 GRAC 공식 등급이 있는 앱은 RCN을 제출해 한국 지역 등급을 override할 수 있다.
- 같은 안내에 따르면 2026년 10월부터 한국 App Store에서 “빈도가 낮은 욕설 및 노골적인 유머”, “빈도가 낮은 성인/선정적 테마”가 `전체`에서 `12+`로 이동한다. 2026-08-29 현재는 향후 변경이므로, 10월 이후 제출이면 질문지와 결과를 다시 확인한다.
- GRAC 지역 pictogram은 게임/엔터테인먼트 카테고리 또는 빈번/강한 simulated gambling 등에 해당할 때 조건부로 확인한다. Dutypark가 Productivity 카테고리라면 자동으로 게임 등급 대상이라고 단정하지 않지만, App Store Connect 기본·보조 카테고리를 확인한다.
- GRAC의 공식 등급 통지를 받으면 [한국 연령 등급 override 절차](https://developer.apple.com/kr/help/app-store-connect/manage-app-information/set-an-app-age-rating/)에 따라 RCN을 등록하고 다음 버전에 반영한다.

최종 연령 등급/질문지 답변: **`최종 검증 후 기입`**.

코드 기준 잠정 답변(User-Generated Content 있음, Messaging/Chat 없음, Social Media 없음, Productivity 주 카테고리 등)은 [App Store Connect submission draft](../docs/app-store/APP_STORE_CONNECT_SUBMISSION_DRAFT.md)에 정리했다. 이는 App Store Connect의 실제 질문 문구에 답하고 계산된 등급을 받은 결과가 아니다.

## 12. 제출 보류 해제 조건

다음 항목을 모두 완료하고 이 문서의 `최종 검증 후 기입`을 실제 결과로 바꾼 뒤에만 HOLD를 해제한다.

- [x] Slack 개인정보 변경 focused test 54/54 PASS; UGC backend/iOS 관련 focused·full 검증 PASS(웹 정규화·private D-Day 예외 반영 완료), Release simulator build도 PASS
- [ ] 웹 cold-start/fetch 실패 fail-open 해소 또는 모든 공유 mutation에 대한 서버 enforcement 확인
- [ ] UGC 모든 서버 mutation 경로 및 첨부·신고·차단 E2E 확인
- [ ] 문의·신고·계정삭제 감사 레코드의 보존기간, snapshot/식별자 최소화, 실패 시 provider credential 파기 기한, 익명화, 법적 예외, 관리자 접근과 탈퇴 UI 고지 결정
- [x] 비동기 계정 삭제의 보통 5분 이내 ETA, 로그아웃 후 receipt 상태 조회, worker 완료 confirmation, 최종 실패·지원 경로를 backend·web·iOS에 구현하고 자동 테스트 통과
- [x] 현재 앱을 기준으로 ko/en App Store 스크린샷 재촬영·재합성·시각 검토
- [ ] 최종 제출 commit의 distribution-signed exported IPA, production APNs entitlement, privacy manifest를 재확인(기존 `268029a3` 산출물은 PASS했으나 이후 제품 변경됨)
- [ ] 최종 distribution Archive가 App Store 제출 요건인 iOS 26 SDK 이상으로 빌드됐는지 재확인
- [ ] 실제 iPhone APNs/OAuth/카메라/PhotosPicker/Files picker 확인
- [ ] disposable 운영 유사 계정으로 202 접수부터 worker `COMPLETED`까지 확인하고, 공동 팀 데이터·OAuth revoke·첨부 정리·세션 폐기·receipt 30일 만료·실패/관리자 재시도·운영 edge rate limit을 끝까지 검증
- [ ] App Store Connect privacy labels, 정책 URL, Review Notes, demo account, backend 확인
- [ ] 저장소에서 활성인 web Services ID에 대해 Developer Account의 한국 소재·Services ID 등록/변경 시점·primary App ID 연결 및 S2S endpoint/JWT/retry/replay/idempotency를 확인하고, Apple 직접 적용 여부의 조건 판정을 별도로 기록
- [ ] 한국 연령 등급 questionnaire 및 필요 시 GRAC RCN 처리 확인
