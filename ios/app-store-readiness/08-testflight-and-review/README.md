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
- [!] 전체 테스트 176개 중 175개가 통과하고 UI 테스트 1개가 실패한다.
- [!] 실패 항목은 Todo 탭의 `todo.add` 요소를 찾지 못한 터치 영역 테스트다.
- [ ] [DutyparkUITests.swift](../../DutyparkUITests/DutyparkUITests.swift)의 실패가 재현 가능한지 확인한다.
- [ ] `todo.add` 식별자 노출 또는 테스트 대기 조건을 수정하고 전체 176개 통과를 만든다.
- [ ] Release Archive에서도 Debug 전용 가정이나 테스트용 인증 플래그가 남지 않는지 확인한다.

현재 실패를 단순 flaky로 분류해 무시하지 않는다. 버튼은 [TodoView.swift](../../Dutypark/Features/Todo/TodoView.swift)에 존재하므로,
접근성 표현이 XCUI 계층에 안정적으로 나타나는지와 Todo 화면의 네트워크 오류가 테스트를 가리는지를 함께 조사한다.

## 2. 업로드 전 빌드 게이트

- [ ] App Store Connect 앱 레코드와 Bundle ID `com.tistory.shanepark.dutypark`가 일치한다.
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
- [ ] 176개 테스트가 모두 통과하며 `todo.add` UI 실패가 재발하지 않는다.
- [ ] 내부 TestFlight에서 운영 로그인, 핵심 CRUD와 production APNs가 실기기로 검증된다.
- [ ] 필요한 경우 외부 TestFlight와 Beta App Review를 통과한다.
- [ ] Review Notes, 데모 계정과 심사 연락처가 준비되고 운영 백엔드 가용 담당자가 지정된다.
- [ ] App Store 메타데이터, App Privacy와 실제 앱 동작이 일치한다.
- [ ] 중단·롤백 기준과 출시 방식이 정해진 상태에서 동일 빌드를 App Review에 제출한다.
