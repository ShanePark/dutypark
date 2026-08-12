# 앱 내 계정 삭제

- 작성일: 2026-08-12
- 최종 확인일: 2026-08-13
- 우선순위: 제출 전 필수
- 상태: 구현 및 검증 중
- 관련 심사 항목: App Review Guideline 5.1.1(v)

## 목표

계정을 만들 수 있는 사용자가 앱 안에서 계정 삭제를 시작하고 완료할 수 있게 한다.
현재 iOS와 백엔드에는 삭제 요청, 접근 종료, 비동기 정리 흐름이 구현되어 있다.
다만 운영 유사 DB, 실제 소셜 공급자 revoke, TestFlight 실기기와 심사 문서 검증이 남아 있으므로 출시 완료로 표시하지 않는다.
단순 로그아웃, 계정 비활성화, 고객센터 문의만으로 완료 처리하지 않는다.

## 현재 확인된 위치

- iOS 5단계 삭제 화면: [AccountDeletionView.swift](../../Dutypark/Features/Settings/AccountDeletionView.swift)
- iOS 설정 진입점: [SettingsView.swift](../../Dutypark/Features/Settings/SettingsView.swift)
- iOS 삭제 API 모델과 호출: [SettingsService.swift](../../Dutypark/Features/Settings/SettingsService.swift)
- iOS 인증 상태: [SessionStore.swift](../../Dutypark/Core/Auth/SessionStore.swift)
- iOS APNs·알림 로컬 정리: [APNsRegistration.swift](../../Dutypark/Features/Notifications/APNsRegistration.swift)
- iOS 소셜 재인증: [MobileOAuthClient.swift](../../Dutypark/Features/Auth/MobileOAuthClient.swift)
- iOS 5개 언어 문자열: [Settings.xcstrings](../../Dutypark/Resources/Settings.xcstrings)
- 웹 공통 인증 클라이언트: [client.ts](../../../frontend/src/api/client.ts)
- 백엔드 삭제 API: [AccountDeletionController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/controller/AccountDeletionController.kt)
- 백엔드 삭제 요청 서비스: [AccountDeletionService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/service/AccountDeletionService.kt)
- 비동기 작업 실행: [AccountDeletionWorker.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionWorker.kt)
- 재시도·backoff 조정: [AccountDeletionJobCoordinator.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionJobCoordinator.kt)
- 파일 정리: [AccountDeletionFileCleaner.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionFileCleaner.kt)
- DB 정리·소유권 이관: [AccountDeletionDatabaseCleaner.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionDatabaseCleaner.kt)
- 관리자 재시도 API: [AdminAccountDeletionController.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/controller/AdminAccountDeletionController.kt)
- 외부 계정 revoke 경계: [AccountDeletionExternalAccountRevoker.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/service/AccountDeletionExternalAccountRevoker.kt)
- 계정 삭제 DB 마이그레이션: [V2.2.27__account_deletion.sql](../../../src/main/resources/db/migration/v2/V2.2.27__account_deletion.sql)
- 로그인 차단: [AuthService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/service/AuthService.kt)
- 백엔드 쿠키 처리: [CookieService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/security/service/CookieService.kt)
- 개인정보 처리방침: [V2.2.28__align_privacy_policy_with_current_data_flows.sql](../../../src/main/resources/db/migration/v2/V2.2.28__align_privacy_policy_with_current_data_flows.sql)
- 최신 이용약관: [V2.2.29__add_terms_and_ai_schedule_consent.sql](../../../src/main/resources/db/migration/v2/V2.2.29__add_terms_and_ai_schedule_consent.sql)

경로가 리팩터링되면 실제 클래스명을 `rg --files`로 다시 찾아 이 문서 링크도 갱신한다.

## 확정된 정책

- [x] 재인증된 삭제 요청을 수락하면 사용자의 접근을 즉시 종료하고 계정을 `DELETION_PENDING`으로 전환한다.
- [x] 실제 파일과 DB 삭제는 durable 비동기 job으로 처리한다.
- [x] 작업 실패는 지수 backoff로 최대 8회 자동 재시도하고, 최종 실패는 관리자 retry API로 재개한다.
- [x] 다인 팀의 관리자는 같은 팀의 활성 member에게 관리자 권한을 이관해야 삭제할 수 있다.
- [x] 관리자 혼자 있는 1인 팀은 계정과 함께 자동 삭제한다.
- [x] 로그인 수단이 없는 보조 계정은 삭제 요청자가 유일한 manager일 때 함께 삭제한다.
- [x] 삭제 요청은 멱등하게 수락하며 이미 존재하는 job을 중복 생성하지 않는다.
- [ ] 법적 보존 의무가 있는 데이터와 보존 기간을 개인정보 처리방침에 적는다.
- [x] `PRIVACY 2026-08-13`에 비동기 계정 삭제, 개별 삭제, 공동 TEAM 데이터·첨부의 보존·이관 예외를 실제 처리 흐름에 맞춰 반영했다.
- [x] `TERMS 2026-08-13`에 비동기 처리, 접근 제한, 공동 데이터·법정 보존 예외와 완료 후 복구 불가를 반영했다.
- [ ] 삭제·이관·보존 데이터의 최종 목록과 법적 근거를 Review Notes에 반영한다.
- [ ] 재가입 시 같은 소셜 식별자를 새 계정으로 허용할지 정한다.

## 도메인별 처리 규칙

### 팀과 권한

- [x] preview API가 팀 관리자 여부, 활성 인원, 자동 삭제 여부와 이관 후보를 반환한다.
- [x] 다인 팀 관리자는 동일 팀의 활성 member를 선택하지 않으면 요청을 거부한다.
- [x] 1인 팀은 팀 일정·근무·첨부파일을 포함해 비동기 작업에서 삭제한다.
- [x] 삭제 요청 트랜잭션에서 member와 team을 잠그고 이관 후보를 다시 검증한다.
- [x] 유지되는 팀의 일정 작성·수정자와 TEAM 첨부파일 소유자를 새 관리자에게 이관한다.

### 관계와 공유 데이터

- [x] 친구, 친구 요청, manager·보조 계정 관계를 삭제한다.
- [x] 개인 일정, Todo, 근무, D-day, 알림과 개인 태그를 삭제한다.
- [x] 삭제되지 않는 팀 콘텐츠는 새 관리자 소유로 유지한다.
- [x] 로그인 불가능한 보조 계정 자동 삭제 대상을 preview에 표시한다.
- [ ] 법적·운영 감사 이력의 익명화 또는 보존 범위를 개인정보 문서에 확정한다.

### 첨부파일

- [x] `SCHEDULE`, `PROFILE`, `TEAM`, `TODO` 컨텍스트와 임시 upload session 파일을 정리한다.
- [x] 삭제되는 개인·팀 파일과 DB 레코드를 durable worker에서 처리한다.
- [x] 유지되는 팀 첨부파일의 소유권은 새 관리자에게 이관한다.
- [x] 파일 또는 DB 처리 실패는 job 실패로 기록하고 자동·관리자 재시도 경로를 제공한다.

### 인증과 외부 연동

- [x] 대상 계정을 `DELETION_PENDING`으로 바꿔 기존 access, 신규 로그인과 refresh를 차단한다.
- [x] 모든 refresh session을 삭제하고 연결된 APNs installation을 제거한다.
- [x] 웹 푸시 subscription을 포함한 인증 관련 데이터를 비동기 정리한다.
- [x] 응답에서 access/refresh cookie를 즉시 clear한다.
- [x] 소셜 OAuth의 `DELETE_ACCOUNT` 목적과 일회성 재인증 proof를 구현한다.
- [x] 외부 revoke를 worker 단계의 재시도 가능한 인터페이스로 분리했다.
- [ ] Kakao·Naver provider-side revoke는 현재 의도적인 no-op이므로 실제 자격 증명 보관과 API 연동을 구현한다.
- [ ] Sign in with Apple 도입 시 durable credential snapshot과 Apple revoke를 구현한다.
- [ ] provider-side revoke 실패와 재시도를 운영 유사 환경에서 검증한다.

### 보조 계정과 impersonation

- [x] 로그인 불가능하며 삭제 요청자가 유일 manager인 보조 계정을 재귀적으로 자동 삭제한다.
- [x] 자동 삭제 보조 계정이 다인 팀의 유일 관리자이면 별도 이관이 필요하므로 요청을 거부한다.
- [x] impersonation 중 preview, 비밀번호·소셜 재인증과 삭제 요청을 차단한다.
- [x] impersonation 거부 사유를 기계 판독 가능한 오류 코드로 반환한다.

## 백엔드 구현 체크리스트

- [x] `GET /api/members/me/deletion` preview와 `POST /api/members/me/deletion` 요청 API를 구현했다.
- [x] 비밀번호 또는 소셜 OAuth proof 중 정확히 하나를 요구하는 재인증을 구현했다.
- [x] 팀 이관 필요·후보 오류와 impersonation 오류 코드를 제공한다.
- [x] 요청 즉시 `DELETION_PENDING`, refresh 무효화, cookie clear를 적용한다.
- [x] DB job과 대상 member·team snapshot을 마이그레이션으로 영속화했다.
- [x] 최대 8회 backoff, stale claim 회수, 멱등 요청과 worker 재실행을 구현했다.
- [x] 최종 실패 job용 `POST /admin/api/account-deletions/{jobId}/retry`를 구현했다.
- [x] 개인·팀 파일 삭제와 유지 팀 소유권 이관을 구현했다.
- [ ] 실제 MySQL Testcontainers 또는 운영 유사 MySQL에서 locking, SQL 순서와 전체 삭제를 검증한다.
- [ ] 운영 감사 로그의 보존 기간과 모니터링·알림을 확정한다.

## iOS 구현 체크리스트

- [x] 설정 화면에 실제 `계정 삭제` 진입점과 전용 sheet를 제공한다.
- [x] 범위 안내, 팀 이관, 재인증, 이름 입력, 최종 파괴 확인의 5단계 흐름을 구현했다.
- [x] 비밀번호와 Kakao·Naver 소셜 재인증을 `DELETE_ACCOUNT` proof로 처리한다.
- [ ] `202 Accepted` 직후 인증·쿠키·APNs와 사용자별 로컬 상태는 즉시 정리하되, 바로 guest 화면으로 보내지 않고 `탈퇴 요청 완료` 화면을 유지한다.
- [ ] 완료 화면에서 요청 성공, 안전한 로그아웃 완료, 비동기 데이터·파일 삭제가 잠시 걸릴 수 있음을 안내하고 사용자가 확인한 뒤 guest 화면으로 이동한다.
- [x] 오류 코드별 재시도와 만료된 proof 재인증 흐름을 구현했다.
- [x] 사용자 문구를 `ko`, `en`, `ja`, `zh-Hans`, `es`로 제공한다.
- [ ] TestFlight 실기기에서 5단계 삭제를 끝까지 검증한다.
- [ ] VoiceOver, 최대 Dynamic Type과 44pt 터치 영역을 실기기로 확인한다.

### 탈퇴 성공 UX 계약

- 서버가 `202 Accepted`를 반환하면 계정은 이미 `DELETION_PENDING`이며 access, login, refresh와 연결된 session을 다시 사용할 수 없어야 한다.
- 클라이언트는 응답 직후 인증 cookie, APNs 등록, badge, 알림과 사용자별 로컬 데이터를 즉시 정리한다.
- 인증 정리와 화면 전환은 별개다. 인증 상태가 끝났더라도 사용자가 완료 안내를 읽을 수 있는 전용 완료 상태를 유지한다.
- 완료 화면에는 `탈퇴 요청 완료`, `안전하게 로그아웃되었습니다`, `데이터와 파일 삭제에는 잠시 시간이 걸릴 수 있습니다`라는 세 의미가 명확히 포함되어야 한다.
- 사용자가 확인 버튼을 누른 뒤에만 guest 화면으로 이동한다. 요청 제출 직후 로그인 화면이나 guest 홈으로 갑자기 전환되어 단순 로그아웃처럼 보여서는 안 된다.
- 완료 화면은 재시도나 취소를 제안하지 않는다. 서버가 요청을 수락한 뒤에는 삭제 작업이 비동기로 계속된다는 사실을 안내한다.
- 이 계약의 iOS 구현과 5개 언어·접근성 검증이 끝날 때까지 위 구현 체크 항목은 `[ ]`로 유지한다.

## Kakao/Naver 신규 가입 후 즉시 탈퇴 시연

이 runbook은 팀에 가입하지 않은 신규 테스트 계정을 기준으로 Kakao와 Naver 각각 수행한다.
수동 시연 절차일 뿐 TestFlight 실기기 검증 완료를 의미하지 않으므로 위 체크 항목은 통과 증거를 별도로 남길 때까지 `[ ]`로 유지한다.

### 사전 조건과 주의사항

- 소셜 계정 `연결 해제(unlink)`는 Dutypark DB의 provider mapping만 제거한다.
- unlink는 Kakao/Naver 계정 삭제, 공급자 앱 연결 해제 또는 공급자에게 부여한 권한 철회가 아니다.
- 기존 Dutypark 계정에 연결된 SNS가 2개 이상이고, 대상 SNS를 해제한 뒤에도 최소 1개의 SNS가 남을 때만 unlink할 수 있다.
- 비밀번호 존재 여부는 unlink 허용 조건에 포함되지 않는다. 비밀번호가 있어도 연결된 SNS가 하나뿐이면 서버가 `409 member.social.unlink.lastAuthenticationMethod`로 차단한다.
- unlink 판단과 마지막 인증수단 보호 근거는 [MemberSocialAccountService.kt](../../../src/main/kotlin/com/tistory/shanepark/dutypark/member/service/MemberSocialAccountService.kt)에서 확인한다.
- iOS unlink 화면과 오류 안내는 [SettingsView.swift](../../Dutypark/Features/Settings/SettingsView.swift), API 호출은 [SettingsService.swift](../../Dutypark/Features/Settings/SettingsService.swift)에서 확인한다.
- 반응형 웹 unlink 화면은 [MemberView.vue](../../../frontend/src/views/member/MemberView.vue), API 호출은 [member.ts](../../../frontend/src/api/member.ts)에서 확인한다.
- 운영 계정이나 실제 개인정보를 사용하지 말고 삭제해도 되는 전용 테스트 SNS 계정과 테스트 데이터만 사용한다.
- 운영 환경에서 시연한다면 로그·스크린샷·화면 녹화에 이름, 이메일, 토큰 등 개인정보가 남지 않게 한다.
- unlink는 iOS 또는 반응형 웹에서 수행할 수 있지만, 아래 신규 계정의 5단계 계정 삭제 시연은 iOS 앱 기준이다.

### 시연 절차

1. Kakao와 Naver가 모두 연결된 기존 Dutypark 계정으로 로그인한다.
2. iOS의 `설정 > 소셜 계정` 또는 반응형 웹 `회원정보 > 소셜 계정` 영역에서 둘 중 시연 대상 Kakao 또는 Naver의 `연결 해제`를 누르고 확인한다.
3. 대상 SNS가 연결 목록에서 사라졌는지 확인한다. 이 단계에서는 Dutypark 내부 mapping만 삭제된다.
4. Dutypark에서 로그아웃한다.
5. 방금 unlink한 동일 SNS로 다시 로그인한다.
6. 기존 Dutypark 계정으로 돌아가지 않고 신규 가입 화면이 나타나는지 확인한 뒤 이름과 필수 약관 절차를 완료한다.
7. 신규 계정이 어떤 팀에도 가입되지 않은 상태인지 확인한다.
8. iOS 앱의 `설정 > 계정 삭제`로 이동해 앱 기준 5단계 흐름을 진행한다.
9. 재인증 단계에서 신규 가입에 사용한 동일 SNS로 본인을 다시 확인한다.
10. 계정 이름을 정확히 입력하고 최종 삭제 요청을 제출한다.
11. 요청 수락 직후 인증·쿠키·APNs와 사용자별 로컬 상태가 정리되면서도 `탈퇴 요청 완료` 화면이 유지되는지 확인한다.
12. 완료 화면에서 안전한 로그아웃과 비동기 데이터·파일 삭제 안내를 읽고 확인 버튼을 누른다.
13. 확인 후 guest 화면으로 이동하고 인증된 화면에 다시 접근할 수 없는지 확인한다.
14. worker의 기본 5초 실행 주기를 고려해 5~10초 기다린다.
15. 같은 SNS로 다시 로그인한다.
16. 신규 가입 화면이 다시 나타나는지 확인해 삭제 worker가 Dutypark의 SNS mapping을 제거했음을 검증한다.

### 기대 결과와 기록

- 연결된 SNS가 하나뿐인 비교 계정에서는 비밀번호 유무와 관계없이 `409` 안내가 나타나고 연결이 유지된다.
- unlink 후 첫 동일 SNS 로그인에서는 신규 가입 화면이 나타난다.
- 신규 계정 삭제 요청 직후에는 완료 안내가 먼저 나타나고, 사용자가 확인한 뒤 guest 상태가 된다.
- worker 처리 후 동일 SNS 로그인에서는 다시 신규 가입 화면이 나타난다.
- 10초 후에도 기존 계정으로 로그인되거나 신규 가입 화면이 나타나지 않으면 재시도를 반복하지 말고 account deletion job 상태와 worker 오류를 확인한다.
- Kakao와 Naver 각각 실행 일시, 앱 빌드, 실행 환경, 결과를 남기되 SNS 식별자와 개인정보는 기록하지 않는다.
- provider-side 권한 철회는 이 시연의 검증 범위가 아니며 별도 미완료 항목으로 유지한다.

## 웹 구현 체크리스트

- [ ] 웹 설정에도 동일한 계정 삭제 기능과 정책 설명을 제공한다.
- [ ] iOS와 동일한 사전 점검 및 재인증 API를 사용한다.
- [ ] 성공 시 서버 세션, 웹 푸시 subscription, Pinia 상태와 사용자 캐시를 정리한다.
- [ ] 웹 계정 삭제를 구현할 때도 `202 Accepted` 직후 인증 상태는 정리하되 완료 안내를 먼저 보여주고 사용자 확인 후 guest 화면으로 이동하는 동일한 UX 계약을 적용한다.
- [ ] 모든 사용자 문구를 `ko`, `en`, `ja`, `zh`, `es` 번역에 추가한다.
- [ ] 모바일·데스크톱, 라이트·다크 모드에서 확인한다.

## 테스트

- [x] 백엔드 계정 삭제 관련 51개 테스트와 [OAuthControllerTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthControllerTest.kt) 16개 테스트가 통과했다.
- [x] [AccountDeletionWorkerIntegrationTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/worker/AccountDeletionWorkerIntegrationTest.kt)의 worker integration 3개가 통과했다.
- [x] [AccountDeletionControllerIntegrationTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/AccountDeletionControllerIntegrationTest.kt)에서 재인증, 팀 이관, 자동 대상과 멱등성을 검증했다.
- [x] [MobileOAuthAccountDeletionControllerTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/MobileOAuthAccountDeletionControllerTest.kt)에서 소셜 삭제 재인증 proof를 검증했다.
- [x] [AdminAccountDeletionControllerTest.kt](../../../src/test/kotlin/com/tistory/shanepark/dutypark/member/accountdeletion/controller/AdminAccountDeletionControllerTest.kt)에서 관리자 retry 조건을 검증했다.
- [x] iOS `build-for-testing`이 성공했다. Dutypark QA iPhone 16 Pro 시뮬레이터(식별자 접두사 `5F480…`)에서 [SettingsFeatureTests.swift](../../DutyparkTests/SettingsFeatureTests.swift), [MobileOAuthClientTests.swift](../../DutyparkTests/MobileOAuthClientTests.swift), [APIClientAuthTests.swift](../../DutyparkTests/APIClientAuthTests.swift), [NotificationFeatureTests.swift](../../DutyparkTests/NotificationFeatureTests.swift)를 실행해 57/57 통과했으며 실패·건너뜀은 각각 0개였다.
- [ ] 실제 MySQL Testcontainers 또는 운영 유사 환경에서 worker·locking·삭제 SQL을 검증한다.
- [ ] Kakao·Naver와 향후 Apple provider-side revoke의 성공·실패·재시도를 검증한다.
- [ ] TestFlight 실기기에서 삭제 진입부터 완료까지 실행하고 VoiceOver·Dynamic Type도 확인한다.

## 완료 조건

- [x] 사용자가 외부 문의 없이 iOS 앱 안에서 삭제 요청을 완료할 수 있다.
- [x] 팀 관리자 이관 또는 1인 팀 자동 삭제 결과와 다음 행동이 화면에 표시된다.
- [x] 서버가 요청 즉시 접근을 차단하고 durable worker로 파일·DB를 정리할 수 있다.
- [ ] 실제 MySQL 또는 운영 유사 환경에서 전체 삭제와 재시도를 검증한다.
- [ ] Kakao·Naver provider-side revoke를 구현하고 Apple 로그인 도입 시 Apple revoke를 추가한다.
- [ ] 웹 설정에 계정 삭제 UI를 제공한다.
- [x] 계정 삭제 정책과 실제 데이터 처리 결과를 `PRIVACY 2026-08-13`에 반영했다. 즉시 접근 차단과 비동기 정리, 공동 TEAM·첨부의 보존·이관 가능성을 구분한다.
- [x] `TERMS 2026-08-13`도 모든 데이터가 요청 즉시 일괄 삭제된다는 오래된 단정을 제거하고 실제 비동기 삭제·공동 데이터 계약과 일치시켰다.
- [ ] App Review Notes에 삭제 메뉴 경로, 비동기 처리와 심사 확인 방법을 적는다.
- [ ] iOS에서 `202 Accepted` 후 완료 안내를 표시하고 사용자 확인 뒤 guest 화면으로 이동하는 성공 UX 계약을 구현한다.
- [ ] TestFlight 실기기, VoiceOver와 Dynamic Type 회귀 테스트를 통과한다.

## 공식 자료

- [Apple: Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Apple App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [Apple: Revoke tokens for Sign in with Apple](https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens)
