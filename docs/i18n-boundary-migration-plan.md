# Dutypark i18n Boundary Final Plan

> Status: Implemented
> Updated: 2026-03-30

이 문서는 기존 `docs/notification-i18n-migration-plan.md`, `docs/notification-i18n-refactor-plan.md`를 통합한 최종 기준 문서다.  
현재 기준으로 서버는 더 이상 사용자 표시 문구를 번역하지 않고, 프론트와 서비스워커가 렌더링 책임을 가진다.

## 1. 최종 목표

- 서버는 사용자용 번역 문자열을 만들지 않는다.
- 인앱 알림은 `type + payload + payloadVersion`만 내려주고 프론트가 렌더링한다.
- push는 상세 텍스트가 아니라 `NotificationType`만 내려주고 서비스워커가 locale별 고정 문구를 렌더링한다.
- 서버는 `preferred_locale`, `push_locale`, `Accept-Language` 기반 처리에 의존하지 않는다.
- 공통 API 에러는 `code + details + fieldErrors` 구조만 사용한다.

## 2. 최종 경계

### 2.1 서버 책임

- 알림 타입과 payload snapshot 저장
- payload version 저장 및 역직렬화
- push 대상 식별과 전송
- 에러 code / details / fieldErrors 반환

서버는 아래를 하지 않는다.

- locale별 메시지 번역
- 인앱 알림 title/content 생성
- push 본문 번역
- 사용자 선호 언어 저장

### 2.2 프론트 책임

- 모든 UI 문구 번역
- API error code를 사용자 메시지로 렌더링
- 인앱 알림 문구 렌더링
- 서비스워커 locale 동기화

### 2.3 서비스워커 책임

- 마지막 앱 locale 저장
- push `type`에 맞는 locale별 고정 문구 렌더링

## 3. 알림 최종 구조

### 3.1 DB

`notifications`는 아래 구조를 기준으로 동작한다.

- `type`
- `reference_type`
- `reference_id`
- `actor_id`
- `payload_json`
- `payload_version`
- `is_read`
- `created_date`
- `modified_date`

제거 완료:

- `title`
- `content`

관련 파일:

- [Notification.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/domain/entity/Notification.kt)
- [V2.2.13__notification_payload_columns.sql](/Users/shane/Documents/GitHub/dutypark/src/main/resources/db/migration/v2/V2.2.13__notification_payload_columns.sql)
- [V2.2.14__notification_cutover_cleanup.sql](/Users/shane/Documents/GitHub/dutypark/src/main/resources/db/migration/v2/V2.2.14__notification_cutover_cleanup.sql)
- [V2.2.15__drop_notification_legacy_text_columns.sql](/Users/shane/Documents/GitHub/dutypark/src/main/resources/db/migration/v2/V2.2.15__drop_notification_legacy_text_columns.sql)

### 3.2 payload 원칙

- 표시 문구에 필요한 값은 모두 `payload_json`에 snapshot으로 저장한다.
- `reference_id`는 이동용이다.
- `actor_id`는 원본 참조용이다.
- 이름, 제목, 프로필 사진 버전 같은 렌더링 데이터는 payload에 넣는다.
- 알림 문구를 만들기 위해 프론트가 추가 DB 조회를 하지 않는다.

관련 파일:

- [NotificationPayload.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/domain/payload/NotificationPayload.kt)
- [NotificationPayloadCodec.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodec.kt)
- [NotificationDto.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/dto/NotificationDto.kt)

## 4. 알림 버전 관리 시스템

### 4.1 백엔드

백엔드는 payload class와 codec mapping을 version 단위로 유지한다.

- payload class는 [NotificationPayload.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/domain/payload/NotificationPayload.kt)에 둔다.
- 버전별 역직렬화 매핑은 [NotificationPayloadCodec.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodec.kt)에 둔다.
- 새 버전이 추가돼도 예전 version class와 codec mapping은 지우지 않는다.

### 4.2 프론트

프론트는 payload DTO와 renderer를 version 단위로 유지한다.

- version별 payload 타입 registry: [index.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/types/index.ts)
- renderer registry 공통 타입: [types.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/notifications/renderers/types.ts)
- V1 renderer 구현: [v1.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/notifications/renderers/v1.ts)
- version registry: [index.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/notifications/renderers/index.ts)
- formatter 진입점: [notificationFormatter.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/notificationFormatter.ts)

원칙:

- 새 `payload.version = 2`를 추가할 때 V1 타입과 V1 renderer를 삭제하지 않는다.
- 새 버전은 별도 DTO와 별도 renderer 파일에 추가한다.
- 언어별 메시지도 새 버전에 필요한 만큼만 추가한다.
- 구버전 payload가 내려와도 기존 renderer로 계속 렌더링 가능해야 한다.

### 4.3 새 버전 추가 절차

1. 백엔드에 새 payload class를 추가한다.
2. codec에 새 version mapping을 추가한다.
3. 프론트 `NotificationPayloadRegistry`에 새 version 타입을 추가한다.
4. `frontend/src/notifications/renderers/v{N}.ts` 파일을 추가한다.
5. registry에 새 version renderer를 연결한다.
6. 언어별 메시지 키를 추가한다.
7. 구버전 테스트를 유지한 채 새 버전 테스트를 추가한다.
8. 버전별 알림 번역 키는 `notifications.items.<messageKey>.v{N}` 네임스페이스에 누적한다.

## 5. Push 최종 구조

push는 `NotificationType`만 기준으로 렌더링한다.

서버 payload 예시:

```json
{
  "type": "SCHEDULE_TAGGED",
  "url": "/duty/12",
  "notificationId": "uuid",
  "unreadCount": 4
}
```

서비스워커는 locale 캐시에 저장된 값만 사용해 본문을 만든다.

관련 파일:

- [PushDtos.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/push/dto/PushDtos.kt)
- [WebPushService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/push/service/WebPushService.kt)
- [PushController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/push/controller/PushController.kt)
- [sw.js](/Users/shane/Documents/GitHub/dutypark/frontend/public/sw.js)
- [serviceWorkerLocale.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/serviceWorkerLocale.ts)
- [usePushNotification.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/composables/usePushNotification.ts)

제거 완료:

- `member.preferred_locale`
- `refresh_token.push_locale`
- push subscribe request의 `locale`
- push payload의 `locale`

관련 migration:

- [V2.2.16__push_locale_and_drop_member_preferred_locale.sql](/Users/shane/Documents/GitHub/dutypark/src/main/resources/db/migration/v2/V2.2.16__push_locale_and_drop_member_preferred_locale.sql)
- [V2.2.17__drop_refresh_token_push_locale.sql](/Users/shane/Documents/GitHub/dutypark/src/main/resources/db/migration/v2/V2.2.17__drop_refresh_token_push_locale.sql)

## 6. 에러 계약 최종 구조

공통 API 에러는 아래 구조만 쓴다.

```json
{
  "status": 400,
  "code": "dutyBatch.template.required",
  "details": {
    "remainingAttempts": 2
  },
  "fieldErrors": [
    {
      "field": "name",
      "code": "team.name.required"
    }
  ]
}
```

관련 파일:

- [DutyParkErrorResponse.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/common/domain/dto/DutyParkErrorResponse.kt)
- [RestExceptionControllerAdvice.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/common/advice/RestExceptionControllerAdvice.kt)
- [resolveApiError.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/resolveApiError.ts)
- [apiErrors.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/i18n/messages/apiErrors.ts)

정리 완료:

- 서버 `messages*.properties` 제거
- `LocalizedMessageResolver` 제거
- `MessageSource` 기반 에러 번역 제거
- 프론트 `response.data.message/error` 직접 소비 제거

## 7. 완료 체크리스트

### 알림

- [x] `notifications.payload_json` 추가
- [x] `notifications.payload_version` 추가
- [x] `title/content` 제거
- [x] 기존 알림 컷오버 삭제
- [x] 백엔드 typed payload 도입
- [x] 프론트 typed payload DTO 도입
- [x] 프론트 versioned renderer registry 도입
- [x] 인앱 알림을 프론트 렌더링으로 전환

### push / locale

- [x] 서비스워커 locale 저장 도입
- [x] push를 type-only 문구 구조로 단순화
- [x] `member.preferred_locale` 제거
- [x] `refresh_token.push_locale` 제거
- [x] push subscribe request locale 제거
- [x] 서버 `Accept-Language` 의존 제거

### 에러

- [x] 공통 API 에러를 `code + details + fieldErrors`로 통일
- [x] 로그인 실패 `remainingAttempts`를 `details`로 이동
- [x] duty batch 결과를 `errorCode + errorDetails` 구조로 통일
- [x] 프론트 error resolver 공통화
- [x] attachment 업로드 에러를 code 기반으로 정리

### 서버 i18n 제거

- [x] `messages.properties` 삭제
- [x] `messages_ko.properties` 삭제
- [x] `messages_ja.properties` 삭제
- [x] `LocalizedMessageResolver` 삭제
- [x] 서버 locale 저장 제거

## 8. 남은 작업

현재 기준 필수 마이그레이션 작업은 모두 완료되었다.

남은 것은 구조 회귀를 막기 위한 후속 안정화 backlog다.

- [x] 개인 duty batch 업로드의 `errorCode + errorDetails` 계약 테스트 추가
- [x] 팀 duty batch 업로드 실패 응답 계약 테스트 추가
- [x] `FileUploader` 업로드 실패 분기 단위 테스트 추가

다음 변경 시 지켜야 할 운영 규칙:

- 새 notification payload version 추가 시 구버전 DTO/renderer를 삭제하지 않는다.
- 새 `NotificationType` 추가 시 인앱 renderer와 서비스워커 push 메시지 맵을 함께 추가한다.
- 새 API 에러 code 추가 시 프론트 `apiErrors` 메시지 키를 함께 추가한다.
