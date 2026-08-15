# TestFlight 및 App Review 실행

## 현재 상태

- 2026-08-15 Xcode Organizer에서 `Dutypark` 1.0 (1) Release Archive 생성, 경고 없는 Validate App 통과와 App Store Connect 업로드 완료를 확인했다. 이어 TestFlight에 Version 1.0 / Build 1이 `Ready to Submit`으로 표시돼 Connect 처리 완료를 확인했다.
- 같은 날 자동 배포를 사용하지 않는 내부 테스트 그룹 `Dutypark Internal`을 생성하고 Version 1.0 / Build 1을 연결했다. 빌드는 `Ready to Test`이며 내부 테스터 1명을 추가했다. 실제 iPhone에 TestFlight를 설치하고 초대 링크를 리딤한 뒤 Dutypark Version 1.0 / Build 1을 설치해 앱 실행과 로그인을 확인했다. 사용한 로그인 방식과 나머지 인증 시나리오는 아직 구분해 검증하지 않았다. 개인 이메일은 문서에 기록하지 않는다.
- 2026-08-14 현재 working tree에서 generic iOS 빌드와 전체 테스트가 성공했다.
- `Dutypark QA iPhone 16 Pro` iOS 26.5 Simulator의 최신 `.xcresult` 요약은 **396개 통과, 0개 실패, 0개 건너뜀**이다. 동적 매개변수 실행을 포함한 device execution은 402개다.
- 이전 기록의 3개 실패는 최신 전체 실행에서 재현되지 않았다. 다만 working tree가 아직 dirty이므로 현재 코드는 제출용 동결 기준선이 아니며, 변경을 동결한 동일 후보에서 다시 검증해야 한다.
- 이 문서는 빌드 생성법이나 Connect 메타데이터가 아니라, 업로드된 후보 빌드를 TestFlight에서 검증하고 App Review에 제출하는 실행 절차만 관리한다.

## 남은 체크

### 후보 빌드 동결과 재검증

- [ ] 제출 후보 소스와 서버 배포 상태를 동결하고 커밋, 마케팅 버전, 빌드 번호를 기록한다.
- [ ] clean working tree의 동일 후보로 generic iOS 빌드와 전체 테스트를 다시 실행한다.
- [x] 이전 3개 실패가 최신 전체 실행에서 재현되지 않고 전체 테스트가 green인 것을 확인했다. clean 후보 재검증은 별도로 남아 있다.
- [x] `Dutypark` 1.0 (1) Release Archive를 생성하고 Organizer에 표시되는 것을 확인한다.
- [x] 생성한 Archive가 Organizer의 Validate App을 경고 없이 통과한 것을 확인한다.
- [x] 검증한 `Dutypark` 1.0 (1) Archive의 App Store Connect 업로드 완료를 Xcode에서 확인한다.
- [x] App Store Connect의 빌드 처리 완료와 `Ready to Submit` 상태를 확인한다.
- [x] TestFlight에 표시된 Version 1.0 / Build 1이 기록한 후보와 동일한지 확인한다.

### 내부 TestFlight

- [x] 자동 배포를 사용하지 않는 내부 그룹 `Dutypark Internal`을 생성한다.
- [x] Version 1.0 / Build 1을 내부 그룹에 연결하고 `Ready to Test` 상태를 확인한다.
- [x] 내부 테스터 1명을 그룹에 추가하고 `Invited` 상태를 확인한다.
- [x] 실제 iPhone에 TestFlight를 설치하고 초대 링크의 리딤을 완료한다.
- [x] TestFlight에서 Dutypark Version 1.0 / Build 1을 설치하고 앱 실행과 로그인 성공을 확인한다.
- [ ] 피드백 이메일, Beta App Description과 `What to Test`를 설정한다.
- [ ] 새 설치, 업데이트, 삭제 후 재설치와 백그라운드 종료 후 세션 복원을 확인한다.
- [ ] 운영 서버의 이메일, 카카오, 네이버와 Apple 로그인 신규 가입·재로그인·연결·충돌·취소를 확인한다.
- [ ] Apple 연결 해제와 Apple-only 계정 탈퇴의 revoke 성공·실패·mismatch를 확인한다.
- [ ] 일정과 Todo의 생성·조회·수정·삭제, Todo 이동·정렬을 확인한다.
- [ ] 팀, 친구, 공개 달력과 첨부파일의 주요 흐름을 확인한다.
- [ ] production APNs 권한, 수신, badge, 알림 탭 이동과 계정 전환을 실제 iPhone에서 확인한다.
- [ ] 운영 AASA의 Universal Link, 로그인 후 목적지 복귀와 웹 fallback을 실제 iPhone에서 확인한다.
- [ ] 한국어·영어, Light/Dark, 큰 Dynamic Type, VoiceOver와 주요 화면 clipping을 실제 기기에서 확인한다.
- [ ] 오프라인·5xx 복구 중 크래시, 멈춤, 데이터 유실과 반복 401이 없는지 확인한다.

### 외부 TestFlight 필요 시

- [ ] 내부 테스트의 출시 차단 이슈를 모두 해소한 뒤 외부 그룹과 공개 범위를 정한다.
- [ ] Beta App Review 연락처, 로그인 정보, 테스트 범위와 알려진 제한을 제공한다.
- [ ] 외부 피드백을 기능, 사용성, 접근성, 환경 문제로 분류해 출시 판단에 반영한다.
- [ ] 수정 빌드는 빌드 번호를 증가시켜 같은 내부 검증부터 반복한다.

### App Review와 제출 당일

- [ ] [App Store Connect 입력 준비](../07-app-store-connect/README.md)의 메타데이터, Privacy, 공개 URL, 전용 계정과 Review Notes를 최종 검수한다.
- [ ] 심사 기간 동안 운영 백엔드, 데이터베이스, OAuth callback, 파일 저장소와 알림 발송을 유지할 담당자를 지정한다.
- [ ] 심사 계정의 주요 탭, 일정, Todo, 팀·친구 테스트 데이터와 재현 절차를 확인한다.
- [ ] 제출 직전에 운영 로그인, 핵심 CRUD, production APNs와 Universal Link를 동일 빌드로 다시 확인한다.
- [ ] 내부 테스트를 통과한 동일 빌드를 선택하고 자동·수동·단계적 출시 방식을 결정해 제출한다.

## 완료 조건

- 동결된 동일 후보에서 generic iOS 빌드와 전체 테스트가 green이고 서명 Archive Validate가 성공한다.
- 내부 TestFlight의 실제 iPhone에서 운영 로그인, 핵심 CRUD, production APNs와 Universal Links를 통과한다.
- 실제 기기 접근성·현지화 점검과 장애 복구 점검에 출시 차단 이슈가 없다.
- 필요한 경우 외부 TestFlight와 Beta App Review를 통과한다.
- App Store 정보, Review Notes와 실제 빌드가 일치하며 운영 대응 담당자가 정해져 있다.
- 검증한 동일 빌드를 App Review에 제출한다.

## 불변 계약

- TestFlight는 production APNs를 사용하며 Debug sandbox 성공으로 대체하지 않는다.
- 후보 빌드를 수정하면 빌드 번호를 증가시키고 내부 검증부터 다시 수행한다.
- 테스트에는 전용 계정과 전용 데이터만 사용하고 실제 사용자 데이터를 변경하지 않는다.
- 로그인·세션 복원·핵심 CRUD 실패, 데이터 노출, 권한 우회, 크래시, 데이터 유실, 반복 인증 해제와 production APNs 오등록은 출시 차단이다.
- 문제가 있는 빌드는 배포·제출하지 않고, 승인 후 출시 전이면 출시를 보류한다.
- 심사 대상 기능을 숨기거나 원격 설정으로 우회하지 않는다.

## 필요한 실행 및 참고

- 로컬 빌드·테스트: [iOS README](../../README.md)
- 릴리스 서명·Archive·업로드: [11-release-engineering/README.md](../11-release-engineering/README.md)
- App Store Connect 입력: [07-app-store-connect/README.md](../07-app-store-connect/README.md)
- APNs 실기기 검증: [05-push-notifications/README.md](../05-push-notifications/README.md)
- Universal Links 검증: [06-associated-domains/README.md](../06-associated-domains/README.md)
- [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Apple: TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Apple: Invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
- [Apple: Submit an app for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app-for-review/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
