# 내 문의 내역 + 앱 내 답변 구현 계획

> 상태: 구현 완료 (2026-08-19)
> 작성일: 2026-08-18
> 선행 문서: [UGC 신고·차단·문의 구현 계획](ugc-report-block-plan.md) (D7 "앱 내 답변 기능 없음"을 이 문서가 대체한다)
> 원칙: **기존 문의 도메인의 최소 확장.** 이 문서에 없는 기능은 만들지 않는다.

이 문서는 병렬 구현을 위한 단일 계약(contract)이다. 데이터 모델, API, 알림 계약, i18n 키 소유권, 파일 소유권을 여기서 확정하고, 각 작업 패키지는 이 문서만 보고 독립적으로 구현·검증할 수 있어야 한다.

---

## 0. 문제

현재 문의(`inquiry`)는 **접수 전용**이다.

- 사용자용 엔드포인트는 `POST /api/inquiries` 하나뿐이고, 조회는 `/admin/api/inquiries`만 존재한다.
- 웹 `SupportView.vue` / iOS `SupportView.swift` 모두 접수 성공 화면만 보여주고 끝난다.
- 안내 문구는 "답변은 입력하신 이메일로 보내드립니다"인데 **백엔드에 메일 발송 인프라가 없다.** 관리자가 어드민 화면에서 문의를 읽고 개인 메일로 직접 회신해야만 답변이 전달된다.
- `inquiry.admin_memo`는 내부 메모라 사용자에게 노출할 수 없다.

결과적으로 사용자는 자신이 낸 문의를 다시 확인할 방법이 전혀 없다.

---

## 1. 확정된 설계 결정

사용자와 논의해 확정한 항목. 구현 중 바꾸지 않는다.

| # | 항목 | 결정 |
|---|---|---|
| D1 | 범위 | 내 문의 내역 조회 **+ 관리자 답변 본문 표시.** `inquiry`에 사용자 공개용 `answer` 컬럼 신설, 어드민 상세 모달에 답변 입력란 추가 |
| D2 | 알림 | 답변 등록 시 기존 인앱 알림 시스템으로 통지(`INQUIRY_ANSWERED`). 웹 푸시·APNs도 기존 경로를 그대로 탄다 |
| D3 | 알림 시점 | **최초 답변 저장 시 1회만** 발송. 이후 답변 수정 시 재발송 없음(오타 수정으로 인한 중복 알림 방지) |
| D4 | 진입점 | 별도 메뉴를 만들지 않고 기존 **문의·지원 화면 안**에 둔다. 로그인 회원에게만 상단 세그먼트 탭 2개(`문의하기` / `내 문의 내역`)를 노출하고, 비로그인 화면은 현재 레이아웃 그대로 유지 |
| D5 | 조회 범위 | `inquiry.member_id`가 본인인 문의만. **이메일 일치 매칭은 하지 않는다**(이메일 소유 검증 절차가 없어 타인 문의 노출 위험) |
| D6 | 관리자 화면 | 웹 전용. iOS 관리자 화면은 변경하지 않는다(선행 문서 D9 유지) |
| D7 | 메일 발송 | 이번 범위에서 메일 인프라를 도입하지 않는다. 비로그인 문의 회신은 지금처럼 관리자 수동 메일 |

### 비목표(Non-goals)

- 문의 스레드(사용자 추가 답글), 메일 발송 인프라, 이메일 소유 검증, 비로그인 문의 조회(토큰/조회번호 방식), 문의 삭제·수정, iOS 관리자 문의 화면, 답변 수정 시 재알림, 답변 첨부파일.

---

## 2. 데이터 모델

`inquiry` 테이블에 컬럼 3개와 인덱스 1개를 추가한다. 기존 마이그레이션은 절대 수정하지 않는다.

**마이그레이션 버전 사전 배정** (동시 세션 충돌 방지 — 작업 시작 시 `ls src/main/resources/db/migration/v2 | sort -V | tail -1`로 `V2.2.41`이 최신인지 확인하고, 아니면 아래를 그만큼 밀고 메인 에이전트에게 알린다):

| 버전 | 내용 | 소유 |
|---|---|---|
| `V2.2.42__inquiry_answer.sql` | `inquiry.answer`, `answered_at`, `answered_by` + `idx_inquiry_member_created` | BE-1 |

```sql
ALTER TABLE inquiry
    ADD COLUMN answer      VARCHAR(2000) NULL,
    ADD COLUMN answered_at DATETIME(6)   NULL,
    ADD COLUMN answered_by BIGINT        NULL;

CREATE INDEX idx_inquiry_member_created ON inquiry (member_id, created_date);
```

`Inquiry` 엔티티에 대응 필드를 추가한다. 셋 다 `protected set`, 갱신은 아래 도메인 메서드로만 한다.

```kotlin
fun writeAnswer(answer: String, adminId: Long, now: LocalDateTime): Boolean  // 최초 답변이면 true
```

- 반환값 `true` = 이전 `answer`가 `null`이었고 이번에 채워짐 → 서비스가 알림 이벤트를 발행한다(D3).
- `answeredAt`/`answeredBy`는 저장할 때마다 갱신한다(마지막 작성 시각·작성자).
- 기존 `changeStatus`의 `closedAt`/`closedBy` 동작은 그대로 둔다.

`notifications` 테이블은 변경 없다. `type`·`reference_type` 모두 `VARCHAR(50)`이라 `INQUIRY_ANSWERED`(17자)·`INQUIRY`(7자)가 들어간다. `reference_id`는 `VARCHAR(50)`이라 문의 UUID(36자)가 들어간다.

---

## 3. 백엔드 API 계약

### 3.1 사용자 — `InquiryController` `/api/inquiries`

| 메서드 | 경로 | 인증 | 설명 |
|---|---|---|---|
| `POST` | `/api/inquiries` | 선택 | **기존 그대로.** 변경 없음 |
| `GET` | `/api/inquiries/me` | **필수**(`@Login`) | 내 문의 목록. `?page=0&size=10`, `created_date DESC` 고정 |

응답: `PageResponse<MyInquiryDto>`

```kotlin
data class MyInquiryDto(
    val id: UUID,
    val email: String,
    val subject: String?,
    val content: String,
    val status: InquiryStatus,   // OPEN | CLOSED
    val createdAt: LocalDateTime,
    val answer: String?,
    val answeredAt: LocalDateTime?,
)
```

**노출 금지 필드: `adminMemo`, `ipAddress`, `closedBy`, `answeredBy`.** `AdminInquiryDto`를 재사용하지 말고 별도 DTO를 쓴다.

리포지토리에 추가:

```kotlin
fun findAllByMemberIdOrderByCreatedDateDesc(memberId: Long, pageable: Pageable): Page<Inquiry>
```

(`@EntityGraph` 불필요 — `member`를 읽지 않는다.)

### 3.2 관리자 — `AdminInquiryController` `/admin/api/inquiries`

기존 `PATCH /{id}/status` 요청에 선택 필드 `answer`를 추가한다. 새 엔드포인트를 만들지 않는다.

```kotlin
data class UpdateInquiryStatusRequest(
    @field:NotNull val status: InquiryStatus,
    @field:Size(max = 1000) val memo: String? = null,
    @field:Size(max = 2000) val answer: String? = null,   // 신규. 사용자에게 공개됨
)
```

- `answer`가 `null`이거나 공백뿐이면 무시한다(기존 답변을 지우지 않는다).
- 답변을 지우는 기능은 만들지 않는다.
- 최초 답변이면 `InquiryAnsweredEvent`를 발행한다. **`inquiry.member`가 `null`(비회원 문의 또는 탈퇴 회원)이면 발행하지 않는다.**

`AdminInquiryDto`에 `answer`, `answeredAt`, `answeredBy`를 추가한다(관리자 화면에서 현재 답변을 다시 보여줘야 함).

### 3.3 알림 계약

`notification/event/NotificationEvents.kt`에 추가(**BE-1 소유** — BE-2와 파일이 겹치지 않도록 이 파일만 BE-1이 편집한다):

```kotlin
data class InquiryAnsweredEvent(
    val inquiryId: UUID,
    val memberId: Long,
    val subject: String?,
)
```

| 항목 | 값 |
|---|---|
| `NotificationType` | `INQUIRY_ANSWERED` |
| `NotificationReferenceType` | `INQUIRY` |
| `referenceId` | 문의 id(UUID 문자열) |
| `actorId` | `null` — **관리자 신원을 노출하지 않는다.** 차단 검사도 자연히 건너뛴다 |
| payload | `InquiryAnsweredPayload(version = 1, subject: String?)` — `ActorNotificationPayload`를 구현하지 **않는다** |
| 푸시 URL | `getNotificationUrl`에 `NotificationReferenceType.INQUIRY -> "/support?tab=history"` 추가 |

`NotificationPayloadCodec.payloadClass`의 `version 1` 분기에 `INQUIRY_ANSWERED -> InquiryAnsweredPayload::class.java`를 추가한다(`when`이 exhaustive이므로 누락 시 컴파일 에러).

리스너는 기존 패턴(`@TransactionalEventListener(AFTER_COMMIT)` + `@Async("notificationExecutor")` + `@Transactional(REQUIRES_NEW)`)을 그대로 따르고 `createNotificationAndSendPush`를 재사용한다.

---

## 4. 클라이언트 동작 명세 (웹·iOS 공통)

### 4.1 문의·지원 화면 구조

- **비로그인**: 현재와 동일(안내 카드 → 문의 폼). 탭을 노출하지 않는다.
- **로그인**: 화면 상단에 세그먼트 탭 2개. 기본 선택은 `문의하기`.
  - `문의하기` 탭: 현재의 안내 카드 + 문의 폼.
  - `내 문의 내역` 탭: `GET /api/inquiries/me` 목록.
- 알림/푸시로 진입하면 `내 문의 내역` 탭이 선택된 상태로 열린다(웹은 `/support?tab=history`).

### 4.2 내 문의 내역 목록

- 항목: 제목(없으면 `제목 없음` 대체 문구) · 접수일 · 상태 배지(`접수됨`/`처리완료`) · **답변 여부 배지**(답변 있음/답변 대기).
- 항목을 누르면 펼쳐서(웹 아코디언 / iOS `DisclosureGroup` 또는 상세 push) 문의 본문 전문과 관리자 답변 전문·답변일을 보여준다.
- 답변이 없으면 "확인 후 답변드리겠습니다" 안내 문구를 보여준다.
- 비어 있으면 빈 상태 문구 + `문의하기` 탭으로 가는 버튼.
- 페이지네이션: 10건씩 `더 보기` 버튼(무한 스크롤 아님).
- 로딩·에러·재시도 처리는 각 플랫폼의 기존 목록 화면 관례를 따른다.

### 4.3 안내 문구 변경 (사용자 공개 카피)

현재 카피가 "이메일로 답변"이라고만 말하는데, 로그인 회원은 앱에서 답변을 받으므로 분기한다.

| 키 | 로그인 | 비로그인 |
|---|---|---|
| `support.form.description` | 답변이 등록되면 알림으로 알려드리고 `내 문의 내역`에서 확인할 수 있다 | 현행 유지(입력한 이메일로 회신) |
| `support.success.description` | `내 문의 내역`에서 확인할 수 있다(최대 24시간) | 현행 유지 |

비로그인 폼 하단에는 "로그인 후 문의하면 앱에서 답변을 확인할 수 있습니다" 한 줄을 덧붙인다.

### 4.4 알림 문구

| 키 | 한국어 | 영어 |
|---|---|---|
| `notifications.items.inquiryAnswered.v1` | `문의 [{subject}]에 답변이 등록되었습니다.` | `Your inquiry [{subject}] has been answered.` |
| `notifications.items.inquiryAnsweredFallback.v1` | `문의에 답변이 등록되었습니다.` | `Your inquiry has been answered.` |

`subject`가 `null`이거나 공백이면 fallback 키를 쓴다(기존 actor 처리 관례와 동일).

---

## 5. 작업 패키지 (WP)

### 의존 관계와 순서

```
BE-1 (도메인·API·이벤트 발행)  ──┐
BE-2 (알림 타입·payload·리스너) ──┴─→ 백엔드 통합 (컴파일 경계: NotificationType enum)
      │
      ├─→ WEB-1 (지원 화면)      ─┐
      ├─→ WEB-2 (관리자·알림 렌더) ─┼─→ FINAL (통합·검증·릴리즈 노트)
      ├─→ IOS-1 (지원 화면)      ─┤
      └─→ IOS-2 (알림 타입·라우팅) ─┘
```

- BE-1과 BE-2는 **파일이 겹치지 않으므로 병렬 가능.** 단 BE-2가 `NotificationType.INQUIRY_ANSWERED`를 추가해야 BE-1의 리스너 호출부가 컴파일된다 → BE-1은 이벤트 **발행**까지만 하고 소비는 BE-2가 한다. 두 WP가 끝나야 `./gradlew compileKotlin`이 통과한다.
- 클라이언트 4개 WP는 백엔드 계약이 이 문서에 확정되어 있으므로 백엔드 완료를 기다리지 않고 병렬 착수한다.

### 공유 파일 주의

`frontend/src/i18n/messages/ko.ts` · `en.ts`는 WEB-1과 WEB-2가 함께 편집한다. **키 블록이 서로 떨어져 있으므로 각자 자기 블록의 고유 앵커만 잡아 편집하고, 파일 전체를 다시 쓰지 않는다.**

| 파일 | 편집 WP | 소유 키 |
|---|---|---|
| `messages/{ko,en}.ts` | WEB-1 | `support.*` |
| `messages/{ko,en}.ts` | WEB-2 | `admin.inquiries.*`, `notifications.items.inquiryAnswered*` |

---

### BE-1 · 문의 답변 도메인 + 사용자 조회 API

**소유 파일**
- `src/main/resources/db/migration/v2/V2.2.42__inquiry_answer.sql` (신규)
- `inquiry/domain/entity/Inquiry.kt`
- `inquiry/domain/dto/InquiryDtos.kt` (`MyInquiryDto` 추가)
- `inquiry/domain/dto/AdminInquiryDtos.kt` (`answer`/`answeredAt`/`answeredBy`, `UpdateInquiryStatusRequest.answer`)
- `inquiry/repository/InquiryRepository.kt`
- `inquiry/service/InquiryService.kt`
- `inquiry/controller/InquiryController.kt`
- `notification/event/NotificationEvents.kt` (`InquiryAnsweredEvent`만 추가)
- 테스트: `inquiry/controller/InquiryControllerTest.kt`, `inquiry/controller/AdminInquiryControllerTest.kt`

**작업**
1. 마이그레이션 + 엔티티 필드 + `writeAnswer` 도메인 메서드.
2. `GET /api/inquiries/me` — 로그인 필수, 본인 `member_id` 문의만, `created_date DESC`, 기본 size 10.
3. `changeStatus`에 `answer` 처리. 공백 무시. 최초 답변 && `member != null`이면 `ApplicationEventPublisher`로 `InquiryAnsweredEvent` 발행.
4. `InquiryAnsweredEvent`를 `NotificationEvents.kt`에 추가.

**검증 기준**
- 실패 테스트 먼저: 다른 회원 문의는 `/me`에 안 나온다 / 비회원 문의(`member_id IS NULL`)는 아무에게도 안 나온다 / 비로그인 호출은 401 / `MyInquiryDto` JSON에 `adminMemo`·`ipAddress`가 없다 / 최초 답변에만 이벤트 1회 발행, 재저장 시 미발행 / `answer`가 공백이면 기존 답변 유지.
- `./gradlew test --tests '*Inquiry*'` (BE-2 완료 후 전체 컴파일 확인)

---

### BE-2 · 문의 답변 알림

**소유 파일**
- `notification/domain/enums/NotificationType.kt` (`INQUIRY_ANSWERED`)
- `notification/domain/enums/NotificationReferenceType.kt` (`INQUIRY`)
- `notification/domain/payload/NotificationPayload.kt` (`InquiryAnsweredPayload`)
- `notification/service/NotificationPayloadCodec.kt`
- `notification/event/NotificationEventListener.kt` (핸들러 + `getNotificationUrl`)
- 테스트: `notification/**` 기존 테스트 파일

**작업**
1. enum·payload·codec 등록.
2. `handleInquiryAnswered` 리스너 — `actorId = null`, `referenceType = INQUIRY`, `referenceId = inquiryId.toString()`.
3. `getNotificationUrl`에 `INQUIRY -> "/support?tab=history"`.

**검증 기준**
- 실패 테스트 먼저: 이벤트 발행 → 수신자에게 `INQUIRY_ANSWERED` 알림 1건 생성, `actorId`가 `null`, payload에 `subject` 보존, 푸시 URL이 `/support?tab=history`.
- `./gradlew test --tests '*Notification*'`

---

### WEB-1 · 지원 화면 탭 + 내 문의 내역

**소유 파일**
- `frontend/src/types/inquiry.ts`
- `frontend/src/api/inquiry.ts`
- `frontend/src/views/support/SupportView.vue`
- (필요 시) `frontend/src/views/support/MyInquiryList.vue` 신규 — `SupportView.vue`가 커지면 분리
- `frontend/src/views/support/SupportView.test.ts`
- `frontend/src/i18n/messages/{ko,en}.ts` 중 **`support.*` 블록만**

**작업**
1. `MyInquiry` 타입 + `inquiryApi.fetchMine(page, size)`.
2. 로그인 시에만 세그먼트 탭 노출. `?tab=history` 쿼리로 초기 탭 결정.
3. 내역 목록(상태·답변 배지, 아코디언 상세, `더 보기`, 빈 상태, 로딩/에러/재시도).
4. §4.3 카피 분기 + 비로그인 안내 한 줄.

**검증 기준**
- 컴포넌트 테스트: 비로그인은 탭 없음 / 로그인은 탭 노출 / `?tab=history` 초기 선택 / 답변 있는 항목은 답변 본문 표시, 없으면 대기 문구 / 빈 목록 상태.
- `npm run type-check` · `npm run build` · `npx vitest run src/views/support src/i18n`

---

### WEB-2 · 관리자 답변 입력 + 알림 렌더러

**소유 파일**
- `frontend/src/types/adminModeration.ts`
- `frontend/src/api/admin.ts` (문의 상태 변경 payload에 `answer`)
- `frontend/src/components/admin/AdminInquiryDetailModal.vue`
- `frontend/src/views/admin/AdminInquiryListView.vue` (답변 여부 표시가 필요하면)
- `frontend/src/types/index.ts` (`NotificationType`/`NotificationReferenceType` 유니온)
- `frontend/src/notifications/renderers/v1.ts`, `renderers/index.ts`
- `frontend/src/composables/useNotificationNavigation.ts` (`INQUIRY -> /support?tab=history`)
- `frontend/src/components/common/NotificationDropdown.vue` (필요 시)
- 테스트: `frontend/src/views/admin/adminModerationViews.test.ts`, `frontend/src/utils/notificationFormatter.test.ts`
- `frontend/src/i18n/messages/{ko,en}.ts` 중 **`admin.inquiries.*` / `notifications.items.inquiryAnswered*` 블록만**

**작업**
1. 어드민 상세 모달에 "사용자에게 보낼 답변" textarea(최대 2000, `CharacterCounter`) — 내부 메모와 시각적으로 명확히 구분하고 "이 내용은 사용자에게 그대로 보입니다" 경고 문구를 단다.
2. 저장 시 `answer`를 함께 전송. 기존 답변이 있으면 프리필.
3. 알림 렌더러 + 라우팅 등록.

**검증 기준**
- 테스트: 답변 입력 후 저장 시 요청 body에 `answer` 포함 / 기존 답변 프리필 / `INQUIRY_ANSWERED` 알림 문구가 subject 유무에 따라 정상/폴백 렌더 / `INQUIRY` 알림 클릭 시 `/support?tab=history`.
- `npm run type-check` · `npm run build` · `npx vitest run src/views/admin src/utils src/i18n`

---

### IOS-1 · 지원 화면 세그먼트 + 내 문의 내역

**소유 파일**
- `ios/Dutypark/Domain/Models/InquiryModels.swift` (`MyInquiryDTO`)
- `ios/Dutypark/Features/Support/SupportRepository.swift` (`fetchMyInquiries`)
- `ios/Dutypark/Features/Support/SupportViewModel.swift`
- `ios/Dutypark/Features/Support/SupportView.swift`
- (필요 시) `ios/Dutypark/Features/Support/MyInquiryListView.swift` 신규
- `ios/Dutypark/Features/Support/Support.xcstrings`
- `ios/DutyparkTests/SupportFeatureTests.swift`

**작업**
1. `PageResponse<MyInquiryDTO>` 디코딩(`AdminRepository`/`SocialRepository` 패턴 재사용).
2. 로그인 상태에서만 세그먼트 `Picker` 노출. 초기 탭을 외부에서 지정할 수 있게 `initialTab` 파라미터를 받는다(IOS-2가 알림 라우팅에 사용).
3. 목록 UI(상태·답변 배지, 상세, `더 보기`, 빈 상태, 로딩/에러/재시도) + §4.3 카피 분기.

**검증 기준**
- 테스트: 비로그인은 세그먼트 없음 / 페이지네이션 누적 / 답변 유무 분기 / 에러 후 재시도.
- `ios/README.md`의 빌드·테스트 명령. 완료 후 `iPhone 13 mini` 시뮬레이터에 설치.

---

### IOS-2 · 알림 타입 + 지원 화면 라우팅

**소유 파일**
- `ios/Dutypark/Domain/Models/NotificationModels.swift` (`inquiryAnswered`, `.inquiry`, payload `subject`)
- `ios/Dutypark/Features/Notifications/NotificationPresentation.swift` (`NotificationRoute.support`, 메시지)
- `ios/Dutypark/App/RootTabView.swift` (`openNotificationRoute`에 support 분기)
- `ios/Dutypark/Resources/Notifications.xcstrings`
- `ios/DutyparkTests/NotificationFeatureTests.swift`

**작업**
1. `NotificationType.inquiryAnswered` / `NotificationReferenceType.inquiry` 디코딩 추가(기존 `.unknown` 폴백은 유지).
2. `NotificationRoute.support` → 더보기 탭의 `SupportView(initialTab: .history)`로 이동.
3. 알림 문구(subject 유무 분기) 로컬라이즈.

**의존**: `SupportView`의 `initialTab` 시그니처는 IOS-1이 소유한다. IOS-2는 그 API가 들어온 뒤 라우팅 분기를 연결한다(그 전까지 모델·문구·테스트를 먼저 끝낼 수 있다).

**검증 기준**
- 테스트: `INQUIRY_ANSWERED` 디코딩 / 알림 문구 정상·폴백 / `INQUIRY` referenceType이 `.support` 라우트로 매핑.
- `ios/README.md`의 빌드·테스트 명령.

---

### FINAL · 통합 (메인 에이전트)

1. 전체 diff 리뷰 — 노출 금지 필드(`adminMemo`, `ipAddress`, `answeredBy`)가 사용자 응답에 새지 않는지 직접 확인.
2. 백엔드: `./gradlew test` (또는 최소 `*Inquiry*`, `*Notification*` + 인접 모듈).
3. 웹: `npm run type-check`, `npm run build`, 전체 `vitest`.
4. iOS: `ios/README.md` 빌드·테스트, `iPhone 13 mini` 설치.
5. PR 생성 후 실제 PR 번호로 릴리즈 노트 1건 추가 (`frontend/src/releaseNotes/README.md` 절차, `npm run release-notes:check`).
6. 선행 문서 `docs/design/ugc-report-block-plan.md`의 D7·비목표("앱 내 문의 답변")가 이 문서로 대체되었음을 주석 한 줄로 표시.
