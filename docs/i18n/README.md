# Dutypark i18n / Error Contract Master Plan

> Status: In Progress
> Updated: 2026-03-31
> Supersedes: `docs/i18n-boundary-migration-plan.md`, `docs/i18n-essential-improvement-report.md`

이 문서는 Dutypark의 i18n 경계, notification versioning, API error contract 상태를 한 곳에서 관리하는 메인 문서다.
완료된 구조와 아직 남은 필수 작업을 분리해서, 다음 작업 우선순위를 바로 판단할 수 있게 정리한다.

## 1. 한 줄 요약

- [x] 서버는 사용자 표시 문구를 번역하지 않는다.
- [x] 프론트와 서비스워커가 사용자-facing 문구를 렌더링한다.
- [x] 인앱 알림은 `type + payload + payload.version` 구조를 사용한다.
- [ ] 공통 API 에러는 모든 user-facing 경로에서 `status + code + details + fieldErrors` 구조로 완전히 수렴한다.
- [ ] 현재 필수 잔여 작업 2개를 끝낸다.
  server error contract outlier 정리
  notification read-side 안전화

## 2. 현재 경계

### 서버 책임

- notification type, payload snapshot, payload version 저장
- push 대상 식별과 전송
- API 에러의 `status`, `code`, `details`, `fieldErrors` 반환

### 프론트 책임

- 모든 UI 문구 번역
- API error code를 사용자 메시지로 렌더링
- 인앱 알림 렌더링

### 서비스워커 책임

- 마지막 앱 locale 저장
- push `type` 기준 locale별 고정 문구 렌더링

## 3. 이미 완료된 구조

### i18n / push / notification 전환

- [x] `messages*.properties`, `LocalizedMessageResolver`, 서버 locale 저장 제거
- [x] `member.preferred_locale`, `refresh_token.push_locale`, push subscribe request의 `locale` 제거
- [x] `notifications.title`, `notifications.content` 제거
- [x] notification payload / payload version 기반 구조 도입
- [x] 프론트 notification renderer registry와 locale 메시지 파일 기반 렌더링 도입
- [x] 서비스워커 locale 저장 및 type-only push 렌더링 도입

### 공통 에러 계약 전환

- [x] `DutyParkErrorResponse` 기반 공통 에러 DTO 정착
- [x] 로그인 실패 `remainingAttempts`를 `details`로 이동
- [x] 프론트 공통 error resolver 도입
- [x] attachment / duty batch 주요 응답을 code-first 계약으로 정리

### 최근 추가로 닫은 항목

- [x] friend request 생성 실패를 code-first `400`으로 정리
- [x] friend accept / reject / cancel / unfriend / demote 실패를 code-first `400`으로 정리
- [x] `/api/auth/refresh` 실패를 빈 `401`이 아닌 표준 error envelope로 정리
- [x] push subscribe / unsubscribe 인증 실패를 `401 + {"success": false}`에서 표준 error envelope로 정리
- [x] 위 변경에 맞춰 REST Docs, controller test, unit test, locale 메시지 키를 갱신

## 4. 현재 필수 잔여 이슈

### 4.1 Server Error Contract

- [ ] `OAuthController.ssoSignup`의 빈 `400` / ad-hoc 검증 실패를 표준 error envelope로 통일
- [ ] `RefreshTokenController.deleteOtherRefreshTokens`의 현재 토큰 쿠키 누락 실패를 표준 error envelope로 통일
- [ ] `PolicyController.getCurrentPolicy`의 invalid type 실패를 표준 error envelope로 고정
- [ ] `SchedulePermissionService`, `TeamService`의 raw prose / legacy `AuthException` 메시지를 code-first로 치환
- [ ] 위 정리 후 `RestExceptionControllerAdvice.normalizeCode()`와 `AuthController.normalizeErrorCode()` 같은 runtime guessing 로직을 축소 또는 제거

완료 체크:

- [ ] user-facing API 실패에서 빈 `400/401`이 남지 않는다
- [ ] `{ "success": false }` 같은 별도 실패 계약이 남지 않는다
- [ ] business-rule 실패가 500으로 새지 않는다

### 4.2 Notification Read-Side Safety

- [ ] 손상된 notification row 1건이 목록 / unread / read 경로 전체에 영향을 주지 않도록 막는다
- [ ] `NotificationPayloadCodec`에 safe decode 결과 타입을 도입한다
- [ ] write-side에서 `(type, version, payload class)` compatibility check를 추가한다
- [ ] `NotificationService.getNotifications`, `getUnreadNotifications`에서 invalid row skip + warning log 정책을 도입한다
- [ ] `markAsRead`에서 invalid payload 정책을 명시적 error code로 고정한다
- [ ] codec / service / controller 테스트로 corruption / unknown version 경로를 고정한다

완료 체크:

- [ ] 손상된 row 1건이 notification UX 전체를 깨뜨리지 않는다
- [ ] unsupported version이 전체 장애로 번지지 않는다
- [ ] 저장 시 unsupported 조합이 차단된다

## 5. 다음 작업 우선순위

### Priority 1. Controller Outlier 정리

- [ ] `OAuthController`
- [ ] `RefreshTokenController`
- [ ] `PolicyController`

검증:

- [ ] `./gradlew test --tests "*OAuthControllerTest" --tests "*RefreshTokenControllerTest" --tests "*PolicyControllerTest"`

### Priority 2. Legacy Permission / Manager Error Code 정리

- [ ] `SchedulePermissionService`
- [ ] `TeamService`

검증:

- [ ] 관련 controller / service test에서 `status`뿐 아니라 `code`까지 확인

### Priority 3. Runtime Guessing 정리

- [ ] `RestExceptionControllerAdvice.normalizeCode()`
- [ ] `AuthController.normalizeErrorCode()`

검증:

- [ ] `./gradlew test --tests "*RestExceptionControllerAdviceTest" --tests "*AuthControllerTest"`

### Priority 4. Notification Read-Side 안전화

- [ ] `NotificationPayloadCodec`
- [ ] `NotificationService`
- [ ] `NotificationController`

검증:

- [ ] `./gradlew test --tests "*NotificationPayloadCodecTest" --tests "*NotificationServiceTest" --tests "*NotificationControllerTest"`

## 6. 후순위 Guardrail

이 항목은 유용하지만 현재 필수는 아니다.

- [ ] 프론트 notification renderer / version coverage 테스트 강화
- [ ] locale 메시지 키 존재 검증 자동화
- [ ] generic fallback warning 강화

## 7. 운영 규칙

- [ ] 새 notification payload version 추가 시 구버전 DTO / renderer / codec mapping을 삭제하지 않는다
- [ ] 새 `NotificationType` 추가 시 인앱 renderer와 서비스워커 push 메시지 맵을 함께 추가한다
- [ ] 새 API error code 추가 시 프론트 locale 메시지 키를 함께 추가한다
- [ ] business-rule 실패는 raw prose가 아니라 code-first 예외로 던진다

## 8. 주요 파일

- [NotificationPayloadCodec.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodec.kt)
- [NotificationService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationService.kt)
- [RestExceptionControllerAdvice.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/common/advice/RestExceptionControllerAdvice.kt)
- [AuthController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/AuthController.kt)
- [PushController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/push/controller/PushController.kt)
- [FriendService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt)
- [resolveApiError.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/resolveApiError.ts)
- [notificationFormatter.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/notificationFormatter.ts)
