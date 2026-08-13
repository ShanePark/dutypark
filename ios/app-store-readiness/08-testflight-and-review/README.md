# TestFlight 및 App Review 실행 가이드

최종 확인일: 2026-08-13

이 문서는 Dutypark iOS 빌드를 내부 TestFlight에서 시작해 App Review 제출과 출시 판단까지 진행하기 위한 실행 체크리스트다.
비밀번호, OAuth 비밀값, APNs 개인 키, 실제 세션 쿠키는 이 문서와 저장소에 기록하지 않는다.

## 관련 문서와 코드

- 전체 배포 선행 조건: [iOS 배포 체크리스트](../../DEPLOYMENT_CHECKLIST.md)
- 로컬 빌드·테스트 명령: [iOS README](../../README.md)
- 버전, 빌드 번호, 기기·방향 설정: [Xcode 프로젝트 설정](../../Dutypark.xcodeproj/project.pbxproj)
- 앱의 API 환경 선택: [AppConfiguration.swift](../../Dutypark/Core/Networking/AppConfiguration.swift)
- 로그인·세션 복원: [SessionStore.swift](../../Dutypark/Core/Auth/SessionStore.swift)
- APNs 등록 흐름: [APNsRegistration.swift](../../Dutypark/Features/Notifications/APNsRegistration.swift)
- 현재 UI 테스트: [DutyparkUITests.swift](../../DutyparkUITests/DutyparkUITests.swift)
- 개인정보 manifest: [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)

## 1. 현재 기준선

- [x] iOS 시뮬레이터용 앱 빌드가 성공한다.
- [x] iPhone 16 Pro(iOS 26.5) 시뮬레이터에서 5개 기본 탭 이동 테스트가 3회 연속 통과한다.
- [x] 같은 시뮬레이터에서 알림·Todo 툴바 44pt 테스트가 1회 통과한다.
- [x] `Dutypark QA iPhone 16 Pro`(iOS 26.5) 시뮬레이터에서 당시 전체 테스트 263개가 3회 연속 통과한다.
- [x] iPhone 13 mini(iOS 26.5) 시뮬레이터에서 당시 UI 테스트 3개를 포함한 전체 테스트 263개가 통과한다.
- [x] 한국어·영어 × Light/Dark UI smoke가 iPhone 16 Pro에서 3회 연속, iPhone 13 mini에서 1회 통과한다.
- [x] 한국어·영어 × Light/Dark × 기본/최대 Dynamic Type 자동 핵심 내비게이션·scale evidence를 두 기기에서 확인한다.
- [x] 최신 전체 테스트 264개를 같은 iPhone 16 Pro 시뮬레이터에서 3회 연속 통과시킨다.
- [x] Debug 인증 UI 테스트가 결정적 fixture만 사용하며 실제 API 요청을 시도하지 않는 것을 fail-fast로 검증한다.
- [x] Release 시뮬레이터 clean build에 Debug 전용 인증·게스트 UI 테스트 플래그가 포함되지 않는다.
- [x] unsigned generic iOS Release Archive 앱 번들에 Debug 전용 가정, 테스트용 인증 플래그·계정과 로컬 개발 주소가 남지 않는다.
- [ ] 배포 서명된 Release Archive에서도 같은 검증을 반복한다.

2026-08-13 iPhone 16 Pro(iOS 26.5) 검증에서 Debug 전용 guest 초기 상태를 로그인 UI 테스트에 명시해
로컬 세션·네트워크 상태와 무관하게 카카오·네이버 로그인 진입을 확인하도록 안정화했다. 같은 기기에서 UI 테스트 3개를 포함한
전체 suite를 새로 3회 연속 실행해 매번 **263/263**(실패·건너뜀 0)으로 통과했고, iPhone 13 mini(iOS 26.5)에서도
UI 테스트 3개를 포함한 전체 suite **263/263**이 통과했다. Release 시뮬레이터 clean build도 성공했고 실행 파일에
`-ui-testing-authenticated`, `-ui-testing-guest` 문자열이 없음을 확인했다. 이후 한국어·영어 × Light/Dark 4개 조합의
홈 탭 label과 설정 theme 접근성 값을 검증하는 UI smoke를 추가했다. 최초 전체 suite 반복에서는 렌더된 홈·탭 UI에
identifier 전파가 늦어져 첫 `ko` × Light가 실패했다. app foreground와 `screen.home` 준비를 bounded wait로 확인하도록
테스트를 보정한 뒤 smoke는 iPhone 16 Pro에서 3회 연속, iPhone 13 mini에서 1회 통과했다. 변경 후 전체 suite도
iPhone 16 Pro에서 새로 3회 연속 **264/264**(실패·건너뜀 0)로 통과했다. 이어서 unsigned generic iOS Release
`clean archive`를 생성해 앱 번들에서 내부 Markdown·소스·테스트 fixture·개발용 파일과 인증/guest UI-test 플래그,
테스트 계정, localhost·저장소 절대 경로가 없고 `PrivacyInfo.xcprivacy` 및 `ko`·`en` localization이 포함된 것을
확인했다. 이 Archive의 Bundle ID는 현재 Xcode 값 `com.tistory.shanepark.dutypark`이며, 출시 후보
`io.github.shanepark.dutypark` 확정 또는 서명·provisioning·entitlement 검증을 의미하지 않는다. 배포 서명된
Release Archive 검증은 별도로 남아 있다.

이어서 iOS 26.5 시뮬레이터의 실제 `content_size`를 `large`와
`accessibility-extra-extra-extra-large`로 설정·조회하며 기본/최대 Dynamic Type을 검증했다.
iPhone 16 Pro에서 4개 locale/theme 조합이 기본·최대 각각 3회 연속, iPhone 13 mini에서 각각 1회 통과했다.
홈·설정 탭의 고정 ID·hittable과 44×44pt 영역·왕복 내비게이션, theme accessibility value를 확인했고,
설정 텍스트는 기본 15.67pt에서 최대 한국어 46.00pt(2.94배), 영어 91.67pt(5.85배, 줄바꿈 포함)로
확대된 frame을 xcresult에 보존했다. 변경 후 전체 suite는 새로 3회 연속 **264/264**(실패·건너뜀 0),
Release Simulator `clean build`도 통과했다. 전체 화면의 수동 clipping·VoiceOver·기능 완주 검증은 남아 있다.

이후 `-ui-testing-authenticated` 실행에서 Home·Calendar·Todo·Team·Settings와 알림·APNs·AI 동의 초기 작업이
Debug 전용 결정적 fixture 또는 no-op을 사용하도록 범위를 완성했다. `APIClient`에는 같은 실행 모드에서 요청이 발생하면
즉시 테스트 앱을 종료하는 Debug 전용 fail-fast를 두어, 오류 alert가 우연히 늦게 나타나지 않은 것과 실제 API 요청 0건을
구분했다. 5탭 이동과 Todo·Settings 진입 뒤 alert 부재도 명시적으로 검증했다. 이 상태에서 UI 테스트 4개는
iPhone 16 Pro(iOS 26.5)에서 3회 연속, iPhone 13 mini(iOS 26.5)에서 1회 통과했고, 전체 suite는 iPhone 16 Pro에서
새로 3회 연속 **264/264**(실패·건너뜀 0)로 통과했다. Release Simulator `clean build`와 unsigned generic iOS
Release `clean archive`도 다시 성공했으며, 두 앱 번들에서 authenticated·guest UI-test 플래그, 테스트 계정,
fixture/fail-fast 문구와 localhost·`127.0.0.1`이 없음을 확인했다. 이는 수동 오프라인·5xx 검증을 대신하지 않는다.

## 2. 업로드 전 빌드 게이트

- [!] Apple 멤버십 승인 후 출시 목표 `io.github.shanepark.dutypark`의 Explicit App ID 가용성을 확인하고 최종 Bundle ID를 확정한다. 현재 Xcode 설정은 아직 `com.tistory.shanepark.dutypark`다.
- [ ] 확정된 Bundle ID, Xcode Release 설정과 App Store Connect 앱 레코드가 모두 일치한다.
- [ ] 유료 배포 Team으로 Release 서명과 프로비저닝이 완료된다.
- [ ] `MARKETING_VERSION`과 `CURRENT_PROJECT_VERSION`을 제출할 값으로 확정한다.
- [ ] 동일 버전을 재업로드할 때는 빌드 번호를 반드시 증가시킨다.
- [ ] Release Archive의 `aps-environment`가 production인지 확인한다.
- [ ] Push Notifications, Associated Domains, Sign in with Apple entitlement를 구현 상태와 맞춘다.
- [ ] 앱 아이콘, 표시 이름, 최소 iOS 버전과 iPhone 대상 설정을 확인한다.
- [ ] Organizer의 Validate App을 통과한다.
- [ ] Xcode Privacy Report와 [PrivacyInfo.xcprivacy](../../Dutypark/PrivacyInfo.xcprivacy)를 대조한다.
- [ ] 수출 규정 질문에 답할 근거를 정리한다.

기준 명령은 [iOS README](../../README.md)의 `xcodebuild ... build`와 `xcodebuild ... test`를 사용한다.
Archive 업로드 방법은 [Apple의 빌드 업로드 안내](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)를 따른다.

## 3. 내부 TestFlight

- [ ] App Store Connect에 처리 완료된 빌드를 선택한다.
- [ ] Beta App Description과 `What to Test`를 실제 구현 상태에 맞게 작성한다.
- [ ] 피드백 이메일과 담당자를 지정한다.
- [ ] 개발자, 운영 담당자 등 소수의 내부 그룹부터 배포한다.
- [ ] 새 설치, 업데이트 설치, 삭제 후 재설치를 각각 확인한다.
- [ ] 백그라운드 종료 후 세션 복원이 동작하는지 확인한다.
- [ ] 운영 서버에서 이메일 로그인이 성공한다.
- [ ] 운영 서버에서 카카오·네이버 로그인이 성공한다.
- [ ] 구현 완료 후 Apple 로그인 신규 가입·재로그인·이메일 가리기를 확인한다.
- [ ] 일정 생성·조회·수정·삭제 CRUD를 확인한다.
- [ ] Todo 생성·상태 이동·정렬·수정·삭제 CRUD를 확인한다.
- [ ] 팀, 친구, 공개 달력, 첨부파일의 핵심 흐름을 확인한다.
- [ ] APNs 권한 허용, 수신, 알림 탭 이동을 실기기에서 확인한다.
- [ ] 로그아웃 후 이전 계정의 알림이 수신되지 않는지 확인한다.
- [ ] 다른 계정으로 로그인했을 때 기기 토큰 소유가 올바르게 전환되는지 확인한다.
- [ ] 크래시, 멈춤, 데이터 유실, 반복 401이 없음을 확인한다.

TestFlight 빌드는 production APNs 환경을 사용하므로 Debug sandbox 성공만으로 대체할 수 없다.
운영 API 점검에는 테스트 전용 데이터만 사용하고 실제 사용자 데이터를 임의로 변경하지 않는다.

## 4. 외부 TestFlight

- [ ] 내부 테스트의 출시 차단 이슈가 모두 해결된 뒤 외부 그룹을 만든다.
- [ ] Beta App Review에 심사 연락처와 필요한 로그인 정보를 제공한다.
- [ ] 외부 테스터가 이해할 수 있는 테스트 범위와 알려진 제한을 작성한다.
- [ ] 초대 링크 공개 범위와 최대 테스터 수를 의도대로 설정한다.
- [ ] 외부 피드백을 기능 결함, 사용성, 접근성, 환경 문제로 분류한다.
- [ ] 수정 빌드는 새 빌드 번호로 업로드하고 재검증한다.
- [ ] 심사 대상 기능을 숨기거나 원격 설정으로 우회하지 않는다.

외부 테스트 절차는 [TestFlight 개요](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)와
[외부 테스터 추가 안내](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)를 따른다.

## 5. App Review 제출 자료

- [ ] App Review 연락처의 이름, 전화번호와 이메일이 실제 응답 가능하다.
- [ ] 심사용 데모 계정은 심사 기간 내내 활성 상태로 유지한다.
- [ ] 데모 계정에는 주요 탭, 일정, Todo, 팀과 친구 기능을 확인할 테스트 데이터가 있다.
- [ ] 2단계 인증이나 외부 OAuth가 필요하면 Review Notes에 정확한 절차를 적는다.
- [ ] Apple 로그인, 소셜 로그인, 회원 탈퇴 위치를 Review Notes에 설명한다.
- [ ] 푸시를 확인하는 절차와 알림 도착에 필요한 조건을 설명한다.
- [ ] 카메라·사진·파일 권한이 필요한 기능과 그 이유를 설명한다.
- [ ] AI 선택 동의 위치(웹·iOS 설정, iOS all-day 저장 선택), Google로 전송되는 일정 날짜·내용, 설정 철회와 수동 시간 입력 경로를 Review Notes에 설명한다.
- [!] Cloud Billing이 활성화된 Google paid service와 DPA 적용 Cloud Project를 확인하기 전에는 production AI 자동 인식을 사용하지 않는다.
- [ ] Universal Link 등 외부 진입 경로가 있다면 테스트 URL을 제공한다.
- [ ] 심사 중 운영 백엔드, 데이터베이스, OAuth callback과 파일 저장소를 계속 가용하게 유지한다.
- [ ] 점검 시간, IP 제한, 관리자 승인 대기 때문에 심사가 막히지 않도록 한다.
- [ ] 데모 계정 비밀번호는 App Store Connect의 보안 필드에만 입력한다.
- [ ] Review Notes에는 비밀키, APNs 키, 운영 관리자 자격 증명을 넣지 않는다.

심사 기준은 제출 직전에 [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)에서 다시 확인한다.
계정이 필요한 앱의 제출 정보는 [App Review 정보 입력 안내](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/provide-app-review-information/)를 따른다.

## 6. 제출 당일 점검

- [ ] 선택한 빌드가 내부 테스트를 통과한 동일 빌드인지 확인한다.
- [ ] App Privacy, 개인정보 처리방침 URL, 지원 URL이 공개 접근 가능하다.
- [ ] 연령 등급, 콘텐츠 권리, 수출 규정과 광고 식별 답변이 사실과 일치한다.
- [ ] 스크린샷과 설명이 현재 UI·기능을 과장하지 않는다.
- [ ] 운영 로그인과 CRUD를 제출 직전에 한 번 더 확인한다.
- [ ] TestFlight production APNs 알림을 제출 직전에 한 번 더 확인한다.
- [ ] 서버 로그와 장애 알림을 심사 기간에 관찰할 담당자를 지정한다.
- [ ] 자동 출시, 수동 출시 또는 단계적 출시 방식을 결정한다.
- [ ] Known issue가 심사 차단인지 출시 후 수정 가능한지 명시적으로 판단한다.

## 7. 중단·롤백 기준

- [ ] 로그인, 세션 복원, 일정 또는 Todo CRUD 실패 시 제출을 중단한다.
- [ ] 회원 간 데이터 노출이나 권한 우회 가능성이 있으면 빌드를 배포하지 않는다.
- [ ] 크래시, 데이터 유실, 반복 인증 해제, production APNs 오등록은 출시 차단으로 본다.
- [ ] 문제가 있는 TestFlight 빌드는 테스터 그룹에서 제거하고 수정 빌드를 새 번호로 올린다.
- [ ] App Review 전이면 제출을 취소하고 수정 빌드로 교체한다.
- [ ] 승인 후 출시 전이면 수동 출시를 보류한다.
- [ ] 출시 후 중대 장애면 App Store 판매 중단 여부와 서버 측 안전 조치를 즉시 판단한다.
- [ ] 롤백 시 데이터베이스 호환성과 구버전 앱의 API 호환성을 먼저 확인한다.

Apple의 버전 제출·상태 관리는 [App Review 제출 개요](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app-for-review/)를 참고한다.

## 완료 조건

- [ ] 시뮬레이터 빌드와 Release Archive 검증이 모두 성공한다.
- [x] 최신 전체 264개 테스트가 3회 연속 통과하며 탭·`todo.add`·로그인 UI 실패가 재발하지 않는다.
- [ ] 내부 TestFlight에서 운영 로그인, 핵심 CRUD와 production APNs가 실기기로 검증된다.
- [ ] 필요한 경우 외부 TestFlight와 Beta App Review를 통과한다.
- [ ] Review Notes, 데모 계정과 심사 연락처가 준비되고 운영 백엔드 가용 담당자가 지정된다.
- [ ] App Store 메타데이터, App Privacy와 실제 앱 동작이 일치한다.
- [ ] 중단·롤백 기준과 출시 방식이 정해진 상태에서 동일 빌드를 App Review에 제출한다.
