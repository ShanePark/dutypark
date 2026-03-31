# Dutypark i18n / Error Handling Essential Improvement Report

> Status: Reviewed
> Updated: 2026-03-30

이 문서는 현재 코드베이스를 다시 검증한 뒤,
"지금 반드시 닫아야 하는 안정성 이슈만" 남기도록 정리한 실행 보고서다.

기존 [i18n-boundary-migration-plan.md](/Users/shane/Documents/GitHub/dutypark/docs/i18n-boundary-migration-plan.md)가
"최종 방향"을 설명하는 문서라면,
이 문서는 "그 방향과 아직 어긋나는 실제 구현"만 추려서 다룬다.

---

## 1. 요약

현재 구조의 큰 방향은 맞다.

- 서버 번역 번들과 `MessageSource` 기반 에러 렌더링은 제거되었다.
- `preferred_locale`, `push_locale`, `Accept-Language` 의존도는 메인 경로에서 사라졌다.
- 인앱 알림은 `type + payload + payload.version` 구조로 전환되었다.
- 프론트는 `resolveApiError.ts`, notification renderer, locale 메시지 파일을 통해 렌더링 책임을 갖고 있다.

하지만 이번 재검증 기준으로 "필수"로 남길 항목은 2개뿐이다.

1. 서버 에러 계약이 아직 닫히지 않았다.
2. notification payload/version read-side blast radius가 너무 크다.

이번 검토에서 필수 항목에서 제외한 것:

- 프론트 notification renderer/version 가드레일 강화

이 항목은 유용하지만,
현재는 이미 top-level `NotificationType` 누락이 타입 수준에서 막히고 있고,
남은 위험도는 "서비스 장애"보다 "새 버전 추가 시 품질 저하"에 가깝다.
즉, 필수 안정화라기보다 후속 guardrail에 가깝다.

---

## 2. 필수 이슈 선정 기준

이번 보고서에서 필수 이슈는 아래 기준을 모두 만족하는 항목만 남겼다.

- 현재 런타임에서 실제 장애 또는 비정상 계약을 만들 수 있는가
- 구조 목표와 실제 구현이 직접 충돌하는가
- blast radius가 큰가
- 현재 코드베이스 기준으로 통제 가능한 범위에서 고칠 수 있는가

이 기준으로 보면,
지금 우선순위는 "에러 계약 정상화"와 "notification read-side 안전화"다.

---

## 3. 필수 이슈 1: 서버 에러 계약이 아직 닫히지 않음

### 3.1 이번 검토에서 실제로 확인한 문제

현재 서버는 "프론트가 code를 보고 메시지를 렌더링한다"는 방향을 택했지만,
실제 구현은 아직 세 층으로 갈라져 있다.

#### A. 예외 생성 시점에 raw prose가 많이 남아 있음

대표 예:

- [FriendService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt)
  - `IllegalArgumentException("Already friend")`
  - `IllegalArgumentException("Already requested")`
  - `IllegalStateException("Already family")`
  - `IllegalStateException("Not family")`
- [SchedulePermissionService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/SchedulePermissionService.kt)
  - `AuthException("login member doesn't have permission ...")`
- [TeamService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/team/service/TeamService.kt)
  - `AuthException("Member is not a team manager")`
  - `AuthException("Member is not a team admin")`

이 중 일부는 `common.badRequest`로 뭉개지고,
일부는 아예 500으로 튈 수 있다.

#### B. 전역 핸들러가 아직 "메시지를 code인지 추측"함

대표 위치:

- [RestExceptionControllerAdvice.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/common/advice/RestExceptionControllerAdvice.kt)

현재 상태:

- `normalizeCode()`가 문자열 정규식과 `legacyCodeMappings`로 runtime 해석을 한다.
- 예외가 code가 아니면 `common.badRequest`, `auth.unauthorized`로 fallback한다.
- `MethodArgumentNotValidException`도 `defaultMessage`를 code처럼 해석한다.

즉, 계약이 "예외 생성 시점의 명시적 code"가 아니라
"핸들러에서 추정한 code"에 일부 의존하고 있다.

#### C. 사용자-facing API 중 일부가 여전히 표준 error envelope을 벗어남

대표 위치:

- [PushController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/push/controller/PushController.kt)
  - 인증 실패 시 `{"success": false}`
- [AuthController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/AuthController.kt)
  - `/refresh` 실패 시 body 없는 `401`
  - controller 내부 `normalizeErrorCode()` 중복 보유
- [OAuthController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthController.kt)
  - `sso/signup/token` 일부 검증 실패가 빈 `400`
- [RefreshTokenController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/member/controller/RefreshTokenController.kt)
  - `deleteOtherRefreshTokens`가 현재 토큰 쿠키 없을 때 빈 `400`
- [PolicyController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/policy/controller/PolicyController.kt)
  - invalid type 시 빈 `400`

#### D. bare `IllegalStateException`가 실제 user path에 남아 있음

이건 이번 검토에서 가장 중요하게 보정한 부분이다.

예:

- [FriendService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt)
  - 가족 요청 시 `Not friend`, `Already family`
  - 가족 해제 시 `Not family`

`RestExceptionControllerAdvice`는 `IllegalStateException`를 처리하지 않는다.
그래서 이런 케이스는 code-based `400`이 아니라
기본 `500` 경로로 새어 나갈 수 있다.

보조 위치:

- [ErrorDetectAdvisor.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/common/slack/advice/ErrorDetectAdvisor.kt)

즉, 지금 문제는 단순히 "generic code가 나온다" 수준이 아니라,
"일부 사용자 입력/권한 실패가 여전히 표준 4xx 계약 밖으로 빠질 수 있다"는 점이다.

### 3.2 왜 이게 지금 필수인가

- 프론트는 `resolveApiError.ts`로 code-first 렌더링을 준비해뒀다.
- 그런데 서버는 여전히 raw prose, runtime guessing, 빈 body, bespoke JSON을 혼용한다.
- 결과적으로 화면별 fallback이 생기고,
  일부 경로는 구조 목표와 다르게 500 또는 generic error로 끝난다.
- 특히 친구/가족 요청, push 구독, auth refresh 같은 경로는 사용자 상호작용이 잦고,
  실패 계약이 흔들리면 UX와 디버깅 비용이 같이 커진다.

### 3.3 현재 문서 초안에서 과했던 해결안

초안의 방향 자체는 맞지만,
아래 두 가지는 현재 코드베이스 기준으로 범위가 너무 컸다.

1. 도메인별 예외 클래스를 대량으로 먼저 만들자는 접근

- `FriendRequestAlreadyRequestedException()` 같은 클래스를 전면 도입하는 건 가능하지만,
  첫 단계로는 비용이 크다.
- 지금 먼저 필요한 것은 "예외 타입의 개수"가 아니라
  "사용자-facing 실패가 code와 status를 잃지 않도록 막는 것"이다.

2. `normalizeCode()`를 바로 제거하는 접근

- 이건 최종적으로 맞는 방향이지만,
  아직 prose/legacy 예외가 많이 남아 있는 상태에서 즉시 제거하면 회귀가 크다.
- 먼저 throw site와 outlier response를 정리한 뒤 제거하는 순서가 맞다.

### 3.4 권장 해결 방향

#### A. 먼저 JSON 계약 outlier부터 닫는다

1차 목표는 "user-facing API 실패 응답이 모두 같은 envelope로 나온다"는 것을 맞추는 것이다.

우선순위:

1. [AuthController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/AuthController.kt)
2. [PushController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/push/controller/PushController.kt)
3. [OAuthController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthController.kt)
4. [RefreshTokenController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/member/controller/RefreshTokenController.kt)
5. [PolicyController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/policy/controller/PolicyController.kt)

권장 기준:

- 실패 응답은 `status + code + details + fieldErrors`만 사용
- body 없는 `400/401` 제거
- `{"success": false}` 제거

#### B. 전면 리팩터링 대신 "명시적 4xx exception"을 얇게 도입한다

현재 코드베이스와 가장 잘 맞는 방법은
"도메인별 예외 클래스 수십 개"보다
"status가 있는 code-first 예외 몇 개"를 도입하는 것이다.

예시:

```kotlin
class BadRequestException(code: String) : DutyparkException(code, null) {
    override val errorCode: Int = 400
}

class ForbiddenException(code: String) : DutyparkException(code, null) {
    override val errorCode: Int = 403
}
```

이렇게 하면:

- prose를 `message`에 억지로 담지 않아도 되고
- controller별 `normalizeErrorCode()` 중복을 줄일 수 있고
- `RestExceptionControllerAdvice`가 status/code를 일관되게 만들 수 있다

#### C. bare `IllegalStateException`는 blanket handler로 덮지 않는다

이건 중요하다.

repo에는 실제 invariant 위반을 뜻하는 `IllegalStateException`도 많다.
예를 들어 `id is null`, `context mismatch`, `session not found` 같은 값은
개발/운영 버그 신호로 남겨두는 편이 맞다.

그래서 권장 방향은:

- 모든 `IllegalStateException`를 한 번에 `400`으로 처리하지 않는다.
- 대신 user-facing business-rule 실패만
  `BadRequestException`, `AuthException`, `ForbiddenException` 같은 명시적 code-first 예외로 치환한다.

즉, 이슈는 "IllegalStateException handler 추가"가 아니라
"잘못된 business-rule 예외 타입을 throw site에서 바로잡는 것"이다.

#### D. 마지막에 runtime guessing을 제거한다

아래 조건이 충족된 뒤에만 제거한다.

- 주요 user-facing throw site가 code-first로 전환됨
- controller outlier response가 정리됨
- 관련 테스트가 status-only가 아니라 code/details/fieldErrors를 본다

그 다음에:

- `legacyCodeMappings` 제거
- `normalizeCode()`의 prose fallback 제거
- [AuthController.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/security/controller/AuthController.kt)의 `normalizeErrorCode()` 제거

### 3.5 상세 작업안

#### 1단계: controller outlier 정리

- `AuthController.refresh`
  - missing/invalid/expired refresh token을 빈 `401`이 아니라 표준 error envelope로 반환
- `PushController.subscribe/unsubscribe`
  - refresh token 미존재/타인 소유/만료 케이스를 `DutyParkErrorResponse`로 통일
- `OAuthController.ssoSignup`
  - `termAgree`, `privacyAgree`, `termsVersion`, `privacyVersion` 검증을 빈 `400` 대신 code/fieldErrors 기반으로 정리
  - 가능하면 DTO validation으로 끌어올리는 편이 좋다
- `RefreshTokenController.deleteOtherRefreshTokens`
  - 현재 토큰 쿠키 누락 시 표준 error envelope 적용
- `PolicyController.getCurrentPolicy`
  - invalid policy type에 표준 error envelope 적용 여부를 결정하고 테스트로 고정

#### 2단계: 실제 사용자 경로의 prose/business-rule 예외 치환

우선순위가 높은 지점:

- [FriendService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt)
  - 친구 요청 중복
  - 자기 자신에게 요청
  - 가족 요청/해제 관련 상태 오류
- [SchedulePermissionService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/SchedulePermissionService.kt)
- [TeamService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/team/service/TeamService.kt)

권장 code 예시:

- `friend.request.self`
- `friend.request.alreadyFriend`
- `friend.request.alreadyRequested`
- `friend.family.notFriend`
- `friend.family.alreadyFamily`
- `friend.family.notFamily`

핵심은 code 이름 자체보다,
"프론트에서 번역 가능한 형태로 안정적으로 식별된다"는 점이다.

#### 3단계: 공통 핸들러 단순화

- `RestExceptionControllerAdvice`는 "명시적 code를 실어 나르는 역할"만 하게 줄인다
- 문자열 추측 로직은 제거한다

### 3.6 테스트 상세

필수 테스트:

- [RestExceptionControllerAdviceTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/common/advice/RestExceptionControllerAdviceTest.kt)
  - legacy mapping 의존 제거 후 contract 유지 확인
- [AuthControllerTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/AuthControllerTest.kt)
  - refresh 실패 body/code 확인
  - impersonate/restore 실패 code 확인
- [PushControllerTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/push/controller/PushControllerTest.kt)
  - 현재 `success=false` 기반 assertion을 표준 error envelope assertion으로 변경
- [OAuthControllerTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/security/controller/OAuthControllerTest.kt)
  - sso signup bad request body/code/fieldErrors 고정
- [RefreshTokenControllerTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/member/controller/RefreshTokenControllerTest.kt)
  - current cookie 누락 케이스 contract 고정
- [FriendControllerTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/member/controller/FriendControllerTest.kt)
  - 현재 없는 failure scenario 테스트 추가
  - 이미 친구, 이미 요청됨, 가족 아님 등의 케이스가 500이 아니라 명시적 4xx code를 반환하는지 고정

### 3.7 완료 기준

- user-facing REST API 실패 응답에서 빈 body가 남아 있지 않다
- bespoke failure contract가 남아 있지 않다
- 실제 business-rule 실패가 bare `IllegalStateException`로 500에 빠지지 않는다
- 프론트가 endpoint별 예외 처리 대신 공통 resolver로 대부분의 실패를 다룰 수 있다

---

## 4. 필수 이슈 2: notification payload/version read-side blast radius가 큼

### 4.1 이번 검토에서 실제로 확인한 문제

알림 구조 자체는 잘 옮겨졌지만,
현재 read-side는 손상 row 1건에 너무 취약하다.

대표 위치:

- [NotificationPayloadCodec.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodec.kt)
- [NotificationService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationService.kt)
- [notification.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/stores/notification.ts)
- [NotificationListView.vue](/Users/shane/Documents/GitHub/dutypark/frontend/src/views/notification/NotificationListView.vue)

현재 동작:

1. `payload_json`이 비어 있으면 `deserialize()`가 `null`
2. `payload_version`이 미지원이면 `IllegalArgumentException`
3. JSON 구조가 type/version과 맞지 않으면 역직렬화 예외
4. `NotificationService.toDto()`는 이를 복구하지 않고 그대로 올림
5. 목록/드롭다운/mark-as-read 경로가 함께 실패할 수 있음

실제 서비스 영향:

- `/api/notifications`
- `/api/notifications/unread`
- `/api/notifications/{id}/read`
- notification polling 중 unread 확인 연쇄
- push redirect 시 `markAsRead` 경로

### 4.2 이 문제를 어떻게 판단해야 하는가

이 이슈는 "자주 발생하는 현재 장애"라기보다,
"한 건 터지면 영향 범위가 너무 큰 구조"에 가깝다.

빈도가 아주 높아 보이지는 않는다.

- 현재 알림 생성 경로는 사실상 [NotificationEventListener.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/event/NotificationEventListener.kt)로 수렴한다.
- `payload_json`은 MySQL JSON column이다.
- 알림 cutover 시점에 [V2.2.14__notification_cutover_cleanup.sql](/Users/shane/Documents/GitHub/dutypark/src/main/resources/db/migration/v2/V2.2.14__notification_cutover_cleanup.sql)로 기존 row도 삭제되었다.

하지만 blast radius는 크다.

- 손상 row 1건이 notification UX 전체를 흔든다.
- 현재 테스트도 이 동작을 "loud failure"로 고정하고 있다.
  - [NotificationPayloadCodecTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodecTest.kt)
  - [NotificationServiceTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationServiceTest.kt)

즉, 발생 확률보다 영향 범위 때문에 필수 이슈로 남겨야 한다.

### 4.3 현재 문서 초안에서 과했던 해결안

초안의 `validator registry` 중심 접근은 현재 기준으로 과하다.

이유:

- 현재 payload는 대부분 Kotlin non-null data class다
- 필수 필드 누락은 Jackson 역직렬화 단계에서 이미 많이 걸린다
- 현재 지원 version도 사실상 `1`뿐이다

즉, 지금 먼저 필요한 것은
"전면 field validator framework"가 아니라
"읽을 때 안 터지게 만들고, 쓸 때 타입/버전 불일치 저장을 막는 것"이다.

### 4.4 권장 해결 방향

#### A. codec에 safe decode 결과를 도입한다

현재처럼 예외를 그대로 전파하지 말고,
decode 결과를 명시적으로 다루는 쪽이 맞다.

예시 방향:

```kotlin
sealed interface NotificationPayloadDecodeResult {
    data class Success(val payload: NotificationPayload) : NotificationPayloadDecodeResult
    data class Invalid(val reason: String) : NotificationPayloadDecodeResult
    data object Missing : NotificationPayloadDecodeResult
}
```

핵심은 타입 이름이 아니라,
"invalid row를 서비스 레이어가 정책적으로 처리할 수 있게 만드는 것"이다.

#### B. write-side는 validator registry 대신 compatibility check로 충분하다

현재 더 필요한 것은
"field validator"가 아니라
"`type + payload.version + payload class` 조합이 실제 codec mapping과 맞는지"를 저장 전에 확인하는 것이다.

즉:

- `NotificationService.createNotification()`에서 지원되지 않는 조합 저장 금지
- `payload_version`과 JSON 내부 `version` mismatch 감지

이 정도면 현재 구조에서 가장 큰 write-side 구멍은 막을 수 있다.

#### C. collection read path는 skip + warning log가 가장 적절하다

권장 정책:

- `getUnreadNotifications`
- `getNotifications`

이 경로에서는 invalid row를 건너뛰고,
notification id / type / payloadVersion 기준으로 warning log를 남긴다.

이 방식이 맞는 이유:

- 목록 전체 장애를 바로 막을 수 있다
- 현재 DTO 계약을 크게 바꾸지 않아도 된다
- synthetic fallback DTO를 새로 설계할 필요가 없다

#### D. single-item read path는 정책을 따로 둔다

`markAsRead`는 현재 응답 계약이 `NotificationDto`다.
그래서 invalid payload에 대해 억지 fallback DTO를 만들기보다,
명시적 error code로 실패시키는 편이 더 낫다.

예:

- `notification.payload.invalid`

이 항목은 list/unread skip보다 우선순위가 낮다.
핵심은 먼저 "목록 전체가 안 깨지는 것"이다.

### 4.5 상세 작업안

#### 1단계: codec 결과 타입과 compatibility check 추가

- [NotificationPayloadCodec.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodec.kt)
  - safe decode API 추가
  - `(type, version)` 지원 여부와 payload class 일치 여부 확인 기능 추가

#### 2단계: collection 경로 방어

- [NotificationService.kt](/Users/shane/Documents/GitHub/dutypark/src/main/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationService.kt)
  - `getUnreadNotifications`에서 invalid row skip
  - `getNotifications`에서 invalid row skip
  - 로그는 조용한 skip이 아니라 warning으로 남김

#### 3단계: single-item 정책 고정

- `markAsRead` invalid payload 정책 결정
- 현재 계약을 유지하려면 표준 error envelope로 실패시키는 쪽이 가장 단순하다

### 4.6 테스트 상세

#### codec 테스트

- [NotificationPayloadCodecTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationPayloadCodecTest.kt)

추가/수정할 것:

- unsupported version이 invalid result로 분류되는지
- type과 payload 구조가 맞지 않을 때 invalid result가 나오는지
- `payload_version`과 JSON 내부 `version` mismatch를 잡는지
- quoted JSON normalize는 계속 통과하는지

#### service 테스트

- [NotificationServiceTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/notification/service/NotificationServiceTest.kt)

추가/수정할 것:

- 손상 row가 있어도 `getUnreadNotifications`가 나머지 정상 row를 반환하는지
- 손상 row가 있어도 `getNotifications`가 나머지 정상 row를 반환하는지
- `createNotification`이 unsupported 조합을 저장 전에 거부하는지
- `markAsRead` invalid 정책이 무엇인지 고정하는지

#### controller 테스트

- [NotificationControllerTest.kt](/Users/shane/Documents/GitHub/dutypark/src/test/kotlin/com/tistory/shanepark/dutypark/notification/controller/NotificationControllerTest.kt)

추가할 것:

- 목록 API가 손상 row가 있어도 `200`과 정상 row를 유지하는지
- unread API도 같은 정책인지
- `markAsRead` invalid row 정책을 문서와 테스트에 함께 고정하는지

### 4.7 완료 기준

- 손상된 notification row 1건이 목록 전체를 깨뜨리지 않는다
- unsupported payload version이 list/unread 전체 장애로 번지지 않는다
- write-side에서 unsupported 조합 저장이 차단된다

---

## 5. 필수 이슈에서 제외하는 항목

### 5.1 프론트 renderer/version guardrail 강화

이번 재검토에서는 이 항목을 필수 범위에서 뺐다.

근거:

- [types.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/notifications/renderers/types.ts)와
  [index.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/notifications/renderers/index.ts) 구조상
  top-level `NotificationType` 누락은 이미 타입 수준에서 막힌다
- [notificationFormatter.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/notificationFormatter.ts)는
  unsupported version에서도 generic fallback을 준다
- [notificationFormatter.test.ts](/Users/shane/Documents/GitHub/dutypark/frontend/src/utils/notificationFormatter.test.ts)는
  현재 v1 renderer 존재 여부와 주요 렌더링 케이스를 이미 검증하고 있다

남아 있는 문제는 주로 아래다.

- 새 version 추가 시 version별 coverage를 더 강하게 잡기
- locale 메시지 키 존재 여부를 자동 검증하기
- generic fallback이 개발 중 과하게 타는지 더 빨리 알아차리기

이건 유용한 후속 작업이지만,
현재 기준으로는 운영 안정성보다 개발 가드레일 성격이 더 강하다.

즉, 알림 read-side 장애를 막기 전의 필수 항목은 아니다.

---

## 6. 유지해도 되는 것

### 6.1 `payload.version`을 payload 내부에 두는 구조

현재 프론트는 `notification.payload.version`을 읽고 renderer를 고른다.
이 구조는 그대로 유지해도 된다.

굳이 top-level `payloadVersion`을 DTO에 중복하지 않는 편이 낫다.
대신 DB의 `payload_version`과 JSON 내부 `version` 일치 여부만 검증하면 충분하다.

### 6.2 payload snapshot 방식

아래 값들을 payload에 snapshot으로 넣는 방향도 유지하는 편이 맞다.

- actor 이름
- schedule/todo 제목
- 프로필 사진 버전

프론트가 알림 문구를 만들기 위해 추가 조회를 하지 않는다는 원칙과 잘 맞는다.

---

## 7. 단계별 실행 계획

### Phase 1. 에러 계약 정상화

목표:

- user-facing 실패 응답을 하나의 JSON 계약으로 수렴
- business-rule 실패가 500으로 새지 않게 정리

작업:

1. `AuthController`, `PushController`, `OAuthController`, `RefreshTokenController`, `PolicyController`의 outlier failure response 정리
2. `BadRequestException` / `ForbiddenException` 같은 얇은 code-first 예외 도입
3. `FriendService`, `SchedulePermissionService`, `TeamService`의 user-facing prose/bare state 예외를 명시적 code 기반으로 치환
4. 마지막에 `normalizeCode()` / `normalizeErrorCode()` 제거

검증:

- `./gradlew test --tests "*RestExceptionControllerAdviceTest" --tests "*AuthControllerTest" --tests "*PushControllerTest" --tests "*OAuthControllerTest" --tests "*RefreshTokenControllerTest" --tests "*FriendControllerTest"`

### Phase 2. notification read-side 안전화

목표:

- 손상 row 1건이 notification UX 전체를 깨뜨리지 않게 만들기

작업:

1. `NotificationPayloadCodec`에 safe decode와 compatibility check 추가
2. `NotificationService`의 list/unread 경로를 skip + warning log 정책으로 전환
3. `markAsRead` invalid 정책 확정
4. codec/service/controller 테스트 갱신

검증:

- `./gradlew test --tests "*NotificationPayloadCodecTest" --tests "*NotificationServiceTest" --tests "*NotificationControllerTest"`

### Optional Later. renderer/version guardrail 강화

목표:

- 새 notification version 추가 시 품질 저하를 더 빨리 발견

작업:

1. version coverage를 더 강하게 검증하는 테스트 추가
2. 실제 locale 메시지 파일을 읽는 key coverage 테스트 추가
3. 개발 환경에서 generic fallback warning 추가 여부 검토

검증:

- `cd frontend && npm run test -- src/utils/notificationFormatter.test.ts`
- `cd frontend && npm run type-check`

---

## 8. 최종 권고

이번 재검토 기준으로,
이 문서에서 정말 필수로 남겨야 할 것은 2개다.

1. 서버 에러 계약을 실제 구현 수준에서 닫는다.
2. notification read-side를 손상 row에 안전하게 만든다.

반대로 프론트 renderer/version guardrail은
"다음 알림 타입/버전 추가 작업 전후에 같이 잡으면 좋은 후속 항목"이지,
지금 반드시 해결해야 하는 핵심 안정성 이슈는 아니다.

즉, 지금은 범위를 넓히기보다
"실제 4xx 계약을 잃는 경로"와
"알림 한 건 때문에 전체 UX가 무너지는 경로"
이 두 군데를 먼저 닫는 것이 가장 효과적이다.
