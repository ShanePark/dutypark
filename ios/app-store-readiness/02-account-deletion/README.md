# 02. 앱 내 계정 삭제

> 상태: 앱·웹·서버 구현 완료 / 법적 보존 정책, 외부 provider revoke, 운영 유사 DB와 TestFlight 검증 대기
> 우선순위: P0
> 최종 확인일: 2026-08-14

[출시 준비 목록으로 돌아가기](../README.md)

## 남은 체크리스트

### 정책과 외부 연동

- [ ] 법정 보존 의무가 있는 데이터, 근거, 보존 기간과 삭제·익명화 방식을 확정해 개인정보 처리방침에 반영한다.
- [ ] 운영 감사 이력과 삭제된 콘텐츠의 최소 증거 보존 범위를 확정한다.
- [ ] 재가입 시 같은 Kakao·Naver·Apple 식별자를 새 계정에 연결할 수 있는지 정책을 정한다.
- [ ] Kakao·Naver provider-side revoke에 필요한 credential 수명주기와 API 연동을 구현한다. 현재 Dutypark mapping 삭제만으로 공급자 권한 철회가 완료됐다고 보지 않는다.
- [ ] Apple·Kakao·Naver revoke 실패가 로컬 mapping 선삭제 없이 durable job 재시도로 이어지는지 운영 유사 환경에서 확인한다.

### 데이터베이스와 운영

- [ ] 실제 MySQL 또는 운영 유사 MySQL에서 member·team locking, SQL 실행 순서, 개인·팀·보조 계정 전체 삭제와 소유권 이관을 검증한다.
- [ ] 파일 삭제와 DB 삭제의 부분 실패, 최대 재시도 소진, stale claim 회수와 관리자 수동 재시도를 검증한다.
- [ ] account deletion job 실패율, 장기 대기와 최종 실패를 탐지할 로그·지표·알림과 담당자를 정한다.
- [ ] 삭제·이관·보존 데이터의 최종 목록과 심사 확인 방법을 App Review Notes에 적는다.

### 실기기·TestFlight

- [ ] TestFlight 실기기에서 범위 안내부터 완료 안내까지 5단계 삭제 흐름을 끝까지 실행한다.
- [ ] 비밀번호, Kakao, Naver, Apple 재인증을 각각 검증한다.
- [ ] 팀 관리자 이관, 1인 팀 자동 삭제와 자동 삭제 대상 보조 계정의 결과를 확인한다.
- [ ] `202 Accepted` 뒤 인증·APNs·로컬 상태가 정리되면서 완료 화면은 유지되고, 사용자 확인 뒤에만 guest로 이동하는지 확인한다.
- [ ] 같은 인증 수단으로 다시 로그인해 삭제 완료 후 신규 가입 흐름이 나타나는지 확인한다.
- [ ] VoiceOver, 최대 Dynamic Type, 44pt 터치 영역과 한국어·영어 문구를 실기기에서 확인한다.

## 완료 조건

- 사용자가 외부 문의 없이 앱 안에서 삭제를 요청하고 완료 결과를 이해할 수 있다.
- 요청 수락 즉시 기존 접근이 차단되고, durable worker가 파일·DB·외부 연결 정리를 멱등하게 완료하거나 관찰 가능한 재시도 상태로 남긴다.
- 공동 데이터의 삭제·보존·이관과 법정 보존 예외가 실제 처리, 이용약관과 개인정보 처리방침에 일치한다.
- 실제 MySQL과 각 소셜 provider를 사용한 정상·실패·재시도 흐름이 검증된다.
- 심사자가 Review Notes와 테스트 계정만으로 계정 삭제를 재현할 수 있다.

## 변하지 않는 정책과 계약

- 재인증된 삭제 요청을 수락하면 계정을 즉시 `DELETION_PENDING`으로 바꾸고 access, login과 refresh를 차단한다.
- 응답은 `202 Accepted`이며 실제 파일·DB 정리는 durable 비동기 job으로 처리한다.
- 삭제 요청은 멱등하고, 실패는 지수 backoff 재시도와 관리자 retry 경로를 가진다.
- 다인 팀의 관리자는 같은 팀의 활성 member에게 관리자 권한을 이관해야 삭제할 수 있다.
- 관리자가 혼자인 1인 팀은 팀 데이터와 함께 자동 삭제한다.
- 로그인할 수 없는 보조 계정은 삭제 요청자가 유일 manager일 때만 자동 삭제한다.
- 유지되는 팀 콘텐츠와 첨부파일의 소유권은 새 관리자에게 이관한다.
- 개인 일정, Todo, 근무, D-day, 알림, 관계, 개인 첨부와 인증 세션은 삭제 대상이다.
- 모든 refresh session과 연결된 APNs installation, Web Push subscription을 정리하고 인증 cookie를 즉시 만료한다.
- 외부 계정은 provider revoke가 필요한 경우 revoke 성공 전에 로컬 mapping을 삭제하지 않는다.
- impersonation 중에는 preview, 재인증과 삭제 요청을 허용하지 않는다.
- 클라이언트는 `202 Accepted` 직후 인증·APNs·사용자별 로컬 상태를 정리하되 완료 안내를 먼저 표시한다. 사용자가 확인하기 전 guest 화면으로 갑자기 전환하지 않는다.

## 구현 위치

- iOS 삭제 화면: [`AccountDeletionView.swift`](../../Dutypark/Features/Settings/AccountDeletionView.swift)
- iOS 완료 화면: [`AccountDeletionAcceptedView.swift`](../../Dutypark/Features/Auth/AccountDeletionAcceptedView.swift)
- iOS API: [`SettingsService.swift`](../../Dutypark/Features/Settings/SettingsService.swift)
- 웹 삭제 화면: [`AccountDeletionModal.vue`](../../../frontend/src/components/member/AccountDeletionModal.vue)
- 서버 API: [`AccountDeletionController.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/controller/AccountDeletionController.kt)
- 삭제 worker: [`AccountDeletionWorker.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionWorker.kt)
- DB 정리: [`AccountDeletionDatabaseCleaner.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionDatabaseCleaner.kt)
- 외부 revoke: [`AccountDeletionExternalAccountRevoker.kt`](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/service/AccountDeletionExternalAccountRevoker.kt)
- migration: [`V2.2.27__account_deletion.sql`](../../../src/main/resources/db/migration/v2/V2.2.27__account_deletion.sql)

## 실행 메모

- TestFlight 시연에는 삭제해도 되는 전용 계정과 테스트 데이터만 사용한다.
- provider unlink는 Dutypark 내부 mapping 제거와 공급자 측 권한 철회를 구분해 기록한다.
- 실행 일시, 앱 버전·빌드, 환경과 성공 여부만 남기고 SNS 식별자, 이름, 이메일과 token은 기록하지 않는다.
- 삭제 요청 후 기존 계정으로 다시 로그인되면 반복 시도하지 말고 deletion job과 worker 오류를 먼저 확인한다.

## 참고

- [Apple: Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [Apple: Revoke tokens for Sign in with Apple](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens)
