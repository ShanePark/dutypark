# UGC 신고·차단·문의 구현 계획 (App Review Guideline 1.2)

> 상태: 설계 확정, 구현 대기
> 작성일: 2026-08-18
> 근거 문서: [ios/app-store-readiness/README.md §1](../../ios/app-store-readiness/README.md) · [App Review Guidelines 1.2 — UGC](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)
> 원칙: **심사를 통과하는 최소 변경.** 이 문서에 없는 기능은 만들지 않는다.

이 문서는 병렬 구현을 위한 단일 계약(contract)이다. 데이터 모델, API, 에러 코드, i18n 키 소유권, 파일 소유권을 여기서 확정하고, 각 작업 패키지는 이 문서만 보고 독립적으로 구현·검증할 수 있어야 한다.

---

## 0. 요약

Apple 1.2 요구사항 4가지에 다음으로 대응한다.

| Apple 요구 | 대응 | 비고 |
|---|---|---|
| 부적절 콘텐츠 필터링 수단 | 자동 필터 없음. 신고 → 24시간 내 삭제·정지하는 사후 조치 + 이용약관 금지 조항 | 콘텐츠가 친구/팀 한정 달력이라는 점을 Review Notes에 설명. 리젝 시 서버 금칙어 필터를 후속 추가 |
| 신고 메커니즘 + 신속 대응 | 회원·일정·Todo 신고(사유 enum + 상세), 웹 관리자 신고 큐, 접수 시 Slack 알림 | 비로그인은 신고 버튼 → 로그인 유도 |
| 악성 사용자 차단 | 양방향 차단(친구 기반 열람·검색·친구요청·알림 차단), 차단 목록·해제 | 같은 팀·매니저 관계의 열람은 유지 |
| 공개된 연락처 | 로그인 없이 열리는 웹 `/support` 페이지 + 앱 내 문의 양식(회신 이메일 필수) + 웹 관리자 문의 큐 | App Store Support URL = `https://dutypark.o-r.kr/support` |
| (부수) 이용 정책 공개 | TERMS 새 버전 발행(금지 콘텐츠·제재 단계·이의제기·24시간 조치) | 재동의 흐름 없음(동의는 가입 시에만 기록됨) |

관리자 조치: 신고 상태 처리(RESOLVED/DISMISSED) + 신고 콘텐츠 삭제 + 계정 정지/해제(로그인 거부 + 세션 폐기).

---

## 1. 확정된 설계 결정

사용자와 논의해 확정한 항목. 구현 중 바꾸지 않는다.

| # | 항목 | 결정 |
|---|---|---|
| D1 | 차단 범위 | 친구/공개 기반 열람만 양방향 차단. **같은 팀·매니저·관리자 열람은 유지.** 검색·친구요청·알림·푸시·태그는 양방향 차단. 차단 시 자동 언프렌드(가족 포함), 대기 중 친구요청 양방향 삭제. 기존 태그는 건드리지 않음(차단 후 신규 태그는 친구 조건 미충족으로 자연 거부) |
| D2 | 신고 대상 | `MEMBER`, `SCHEDULE`, `TODO` (첨부는 부모 일정/Todo 신고로 커버). `target_type` enum으로 확장 가능 |
| D3 | 관리자 조치 | 상태 처리 + 신고 콘텐츠 삭제(일정/Todo) + 계정 정지·해제 |
| D4 | 필터링 | 자동 필터 없음(사후 조치). 리젝 시 후속 |
| D5 | 비로그인 신고 | 공개 달력에 신고 버튼 노출, 누르면 로그인 유도(로그인 후 원래 위치로 복귀). 익명 신고 없음 |
| D6 | 연락처 | 이메일 노출 대신 앱 내 문의 양식. 비로그인도 작성 가능, 회신 이메일 필수, IP 기반 rate limit |
| D7 | 문의 처리 | 웹 관리자 목록·상태(OPEN/CLOSED)·메모. 회신은 기록된 이메일로 관리자가 수동 발송(앱 내 답변 기능 없음) |
| D8 | 이용 정책 | TERMS 새 버전 발행(마이그레이션). 새 PolicyType 없음 |
| D9 | iOS 관리자 | 신고·문의 관리 화면은 **웹만.** iOS 관리자 화면 변경 없음 |
| D10 | 신고 사유 | enum(`SPAM`, `HARASSMENT`, `INAPPROPRIATE_CONTENT`, `IMPERSONATION`, `OTHER`) + 선택 상세(≤500자, `OTHER`면 필수) |
| D11 | 신고 스냅샷 | 신고 시점 콘텐츠 요약을 신고 레코드에 저장 + 관리자 화면에 현재 달력 링크 |
| D12 | 차단 진입점 | (a) 타인 달력 헤더 `⋯` 메뉴, (b) 친구 카드 케밥 메뉴. 검색 결과·친구요청 행에는 두지 않음 |
| D13 | 신고→차단 | 신고 폼에 "이 사용자도 차단" 체크박스(`alsoBlock`). 서버가 한 트랜잭션에서 처리 |
| D14 | 정지 의미 | `MemberStatus.SUSPENDED`: 로그인·refresh·재인증·impersonate 거부 + 기존 세션 전부 폐기. 콘텐츠는 유지(개별 삭제로 처리). 관리자가 해제 가능. 기간별 단계 없음(정책 문구로만) |
| D15 | 차단 목록 위치 | 친구 관리 화면(웹 `FriendsView`, iOS `SocialView`) 안의 "차단한 사용자" 섹션. **두 뷰 모두 이미 크므로(805줄/1408줄) 컴포넌트 추출 리팩토링을 함께 진행** |

### 비목표(Non-goals)

- 자동 금칙어/이미지 필터, 이의제기 전용 화면, 신고자 통지, 앱 내 문의 답변, 정지 기간 스케줄러, iOS 관리자 신고 화면, 팀 관계 차단, 첨부파일 단독 신고, 익명 신고, 신고 남용 방지 rate limit(로그인 필수로 대체).

---

## 2. 데이터 모델

모든 신규 테이블은 `EntityBase`(ULID 기반 `CHAR(36)` id, `created_date`, `modified_date`) 규약을 따른다. 마이그레이션은 `src/main/resources/db/migration/v2/`, MySQL 문법, 테스트는 H2 MySQL 모드.

**마이그레이션 버전 사전 배정** (동시 세션 충돌 방지 — 작업 시작 시 `ls src/main/resources/db/migration/v2 | sort -V | tail -1`로 `V2.2.37`이 최신인지 확인하고, 아니면 아래 4개를 같은 오프셋으로 밀고 메인 에이전트에게 알린다):

| 버전 | 내용 | 소유 |
|---|---|---|
| `V2.2.38__member_block.sql` | `member_block` | BE-1 |
| `V2.2.39__content_report.sql` | `content_report` | BE-2 |
| `V2.2.40__inquiry.sql` | `inquiry` | BE-4 |
| `V2.2.41__publish_terms_with_community_guidelines.sql` | TERMS 새 버전 INSERT | BE-5 |

`member.status`는 `VARCHAR(30)`이므로 `SUSPENDED` 추가에 마이그레이션 불필요.

### 2.1 `member_block`

```sql
CREATE TABLE member_block (
    id             CHAR(36)    NOT NULL PRIMARY KEY,
    blocker_id     BIGINT      NOT NULL,
    blocked_id     BIGINT      NOT NULL,
    created_date   DATETIME(6) NOT NULL,
    modified_date  DATETIME(6) NOT NULL,
    CONSTRAINT uk_member_block_pair UNIQUE (blocker_id, blocked_id),
    CONSTRAINT fk_member_block_blocker FOREIGN KEY (blocker_id) REFERENCES member (id) ON DELETE CASCADE,
    CONSTRAINT fk_member_block_blocked FOREIGN KEY (blocked_id) REFERENCES member (id) ON DELETE CASCADE
);
CREATE INDEX idx_member_block_blocked ON member_block (blocked_id);
```

- `ON DELETE CASCADE`: 계정 삭제 워커(`AccountDeletionDatabaseCleaner`, 테이블별 명시 `delete` 후 `member` 삭제)가 새 테이블을 몰라도 DB가 정리하도록. 클리너는 수정하지 않는다(3개 WP가 같은 파일을 만지는 충돌 회피). **BE-1/BE-2/BE-4는 각자 `AccountDeletionWorkerIntegrationTest`를 실행해 통과를 확인**하고, FINAL의 수동 E2E에서 차단·신고·문의 레코드가 있는 계정을 실제 MySQL(dev DB)에서 삭제해 본다(H2와 MySQL의 cascade 동작 차이 확인).

### 2.2 `content_report`

```sql
CREATE TABLE content_report (
    id                  CHAR(36)     NOT NULL PRIMARY KEY,
    reporter_id         BIGINT       NULL,               -- 신고자 탈퇴 시 NULL 유지(증거 보존)
    reported_member_id  BIGINT       NULL,               -- 피신고자(콘텐츠 소유자). 탈퇴 시 NULL
    target_type         VARCHAR(20)  NOT NULL,           -- MEMBER | SCHEDULE | TODO
    target_id           VARCHAR(36)  NOT NULL,           -- MEMBER면 Long 문자열, 나머지는 UUID
    reason              VARCHAR(30)  NOT NULL,           -- SPAM | HARASSMENT | INAPPROPRIATE_CONTENT | IMPERSONATION | OTHER
    detail              VARCHAR(500) NULL,
    content_snapshot    TEXT         NOT NULL,           -- 신고 시점 요약(§2.2.1)
    reporter_name       VARCHAR(50)  NOT NULL,           -- 스냅샷(탈퇴 대비)
    reported_member_name VARCHAR(50) NOT NULL,           -- 스냅샷
    status              VARCHAR(20)  NOT NULL,           -- OPEN | RESOLVED | DISMISSED
    admin_memo          VARCHAR(1000) NULL,
    resolved_at         DATETIME(6)  NULL,
    resolved_by         BIGINT       NULL,
    created_date        DATETIME(6)  NOT NULL,
    modified_date       DATETIME(6)  NOT NULL,
    CONSTRAINT fk_content_report_reporter FOREIGN KEY (reporter_id) REFERENCES member (id) ON DELETE SET NULL,
    CONSTRAINT fk_content_report_reported FOREIGN KEY (reported_member_id) REFERENCES member (id) ON DELETE SET NULL
);
CREATE INDEX idx_content_report_status_created ON content_report (status, created_date);
CREATE INDEX idx_content_report_reporter_target ON content_report (reporter_id, target_type, target_id);
```

#### 2.2.1 스냅샷 규칙

서비스에서 문자열로 조립(JSON 아님, 관리자 화면에 그대로 표시):

- `MEMBER`: `이름: {name}\n프로필 사진: 있음/없음(version {n})`
- `SCHEDULE`: `제목: {content}\n내용: {description ≤300자}\n첨부: {파일명, ...}` (첨부는 `AttachmentRepository.findAllByContextTypeAndContextId(SCHEDULE, id)`)
- `TODO`: `제목: {title}\n내용: {content ≤300자}\n첨부: {파일명, ...}`

### 2.3 `inquiry`

```sql
CREATE TABLE inquiry (
    id             CHAR(36)      NOT NULL PRIMARY KEY,
    member_id      BIGINT        NULL,                  -- 비로그인이면 NULL
    email          VARCHAR(255)  NOT NULL,
    subject        VARCHAR(100)  NULL,
    content        VARCHAR(2000) NOT NULL,
    ip_address     VARCHAR(45)   NOT NULL,
    status         VARCHAR(20)   NOT NULL,              -- OPEN | CLOSED
    admin_memo     VARCHAR(1000) NULL,
    closed_at      DATETIME(6)   NULL,
    closed_by      BIGINT        NULL,
    created_date   DATETIME(6)   NOT NULL,
    modified_date  DATETIME(6)   NOT NULL,
    CONSTRAINT fk_inquiry_member FOREIGN KEY (member_id) REFERENCES member (id) ON DELETE SET NULL
);
CREATE INDEX idx_inquiry_status_created ON inquiry (status, created_date);
CREATE INDEX idx_inquiry_ip_created ON inquiry (ip_address, created_date);
```

- rate limit은 별도 테이블 없이 이 테이블을 카운트한다(§4.4).

### 2.4 `MemberStatus`

`ACTIVE, DELETION_PENDING` → `ACTIVE, DELETION_PENDING, SUSPENDED`. `Member`에 `suspend()`(ACTIVE→SUSPENDED, `check`) / `reinstate()`(SUSPENDED→ACTIVE) 추가. `status`의 `protected set` 유지.

---

## 3. 백엔드 API 계약

기존 규약: 컨트롤러는 `@Login loginMember: LoginMember` 주입, 에러는 `DutyparkException` 계열에 **메시지 키**만 담아 던지고 클라이언트가 번역(`RestExceptionControllerAdvice`; 400=`BadRequestException`, 401=`AuthException`, 429=`RateLimitException`, 404=`NoSuchElementException` 매핑, 409는 도메인 예외에 `errorCode` 인자), 관리자 API는 `AdminAuthFilter`가 `/admin/*` URL 패턴으로 자동 보호(`SecurityConfig.kt:107`), 페이징은 `PageResponse<T>` + `@PageableDefault(size = 10)`.

### 3.1 차단 — `BlockController` `/api/blocks`

| Method | Path | 요청 | 응답 | 비고 |
|---|---|---|---|---|
| `POST` | `/api/blocks/{memberId}` | — | `200` | 멱등. 자기 자신 → `400 block.self`. 대상 없음 → `404` |
| `DELETE` | `/api/blocks/{memberId}` | — | `200` | 멱등 |
| `GET` | `/api/blocks` | — | `List<BlockedMemberDto>` | 페이징 없음(차단 목록은 소규모) |

```kotlin
data class BlockedMemberDto(
    val id: Long, val name: String,
    val hasProfilePhoto: Boolean, val profilePhotoVersion: Long,
    val blockedAt: LocalDateTime,
)
```

`BlockService` 공개 시그니처(다른 패키지가 의존):

```kotlin
@Service @Transactional
class BlockService(...) {
    fun block(loginMemberId: Long, targetMemberId: Long)          // 멱등. 아래 부수효과 포함
    fun unblock(loginMemberId: Long, targetMemberId: Long)        // 멱등
    fun findBlockedMembers(loginMemberId: Long): List<BlockedMemberDto>
    @Transactional(readOnly = true)
    fun isBlockedEitherWay(memberId1: Long, memberId2: Long): Boolean
}
```

`block()` 부수효과(같은 트랜잭션): (1) `member_block` upsert, (2) 양방향 `FriendRelation` 삭제(가족 포함; `FriendService.unfriend`의 관계 삭제 로직 재사용하되 "친구가 아니면 예외"는 던지지 않음), (3) 양방향 `PENDING` `FriendRequest` 삭제. 알림은 만들지 않는다(차단은 상대에게 알리지 않음).

### 3.2 차단 강제 지점(BE-1 소유)

| 지점 | 변경 |
|---|---|
| `FriendService.isVisible` ([FriendService.kt:260](../../src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt)) | admin/self/same-team/manager 단축 평가 **뒤**, `when (targetMember.calendarVisibility)` **앞**에 `if (blockService.isBlockedEitherWay(login.id, targetMember.id)) return false` 삽입. (D1: 팀·매니저 열람 유지) |
| `MemberRepository.searchPossibleFriends` JPQL ([MemberRepository.kt:60](../../src/main/kotlin/com/tistory/shanepark/dutypark/member/repository/MemberRepository.kt)) | `AND m.id NOT IN (SELECT b.blocked.id FROM MemberBlock b WHERE b.blocker.id = :memberId) AND m.id NOT IN (SELECT b.blocker.id FROM MemberBlock b WHERE b.blocked.id = :memberId)` 두 절 추가(countQuery 동일) |
| `FriendService.sendFriendRequest` / `sendFamilyRequest` | 대상 로드 직후 `isBlockedEitherWay` → `BadRequestException("friend.request.blocked")` |
| `NotificationEventListener.createNotificationAndSendPush` ([NotificationEventListener.kt:190](../../src/main/kotlin/com/tistory/shanepark/dutypark/notification/event/NotificationEventListener.kt)) | `actorId != null && isBlockedEitherWay(actorId, memberId)`이면 알림 생성·푸시 모두 skip(로그만) |

순환 의존 주의: `BlockService`가 `FriendRelationRepository`/`FriendRequestRepository`를 직접 쓰고, `FriendService`가 `BlockService`를 주입한다(`BlockService` → `FriendService` 의존 금지).

### 3.3 신고 — `ReportController` `/api/reports`

| Method | Path | 요청 | 응답 |
|---|---|---|---|
| `POST` | `/api/reports` | `CreateReportRequest` | `201 { id }`; 같은 (신고자, target_type, target_id)의 `OPEN` 신고가 이미 있으면 `200 { id }`(멱등) |

```kotlin
data class CreateReportRequest(
    @field:NotNull val targetType: ReportTargetType,      // MEMBER | SCHEDULE | TODO
    @field:NotBlank val targetId: String,
    @field:NotNull val reason: ReportReason,
    @field:Size(max = 500) val detail: String?,           // reason == OTHER 이면 필수 → 400 report.detail.required
    val alsoBlock: Boolean = false,
)
```

서버 처리 순서: 대상 조회(없으면 `404`) → 소유자 결정(`MEMBER`: 본인, `SCHEDULE`: `schedule.member`, `TODO`: `todo.member`) → 소유자 == 신고자면 `400 report.self` → 스냅샷 조립 → 저장(`status = OPEN`) → `alsoBlock`이면 `blockService.block(reporter, owner)` → `@SlackNotification` 로 운영자 알림(서비스 메서드에 애노테이션; 기존 AOP 재사용). 신고자가 대상을 현재 볼 수 있는지는 검사하지 않는다(차단 후에도 신고 가능해야 함).

`@SlackNotification`(`common/slack/aspect/SlackNotificationAspect.kt`)은 메서드 이름과 **인자 toString**을 Slack으로 보낸다. 컨트롤러에서 호출되는 공개 서비스 메서드(`ReportService.createReport(loginMemberId, request)`, `InquiryService.createInquiry(memberId?, request, ip)`)에 붙이면 운영자가 접수 내용을 바로 본다(비공개 운영 채널 전제, "신속한 대응"의 실질 수단). 같은 빈 내부 호출에는 프록시가 적용되지 않는다.

### 3.4 문의 — `InquiryController` `/api/inquiries`

| Method | Path | 인증 | 요청 | 응답 |
|---|---|---|---|---|
| `POST` | `/api/inquiries` | `@Login(required = false)` | `CreateInquiryRequest` | `201 { id }` |

```kotlin
data class CreateInquiryRequest(
    @field:NotBlank @field:Email @field:Size(max = 255) val email: String,
    @field:Size(max = 100) val subject: String?,
    @field:NotBlank @field:Size(max = 2000) val content: String,
)
```

- 로그인 상태면 `member_id` 기록(이메일은 요청값 그대로 저장 — 클라이언트가 계정 이메일을 미리 채움).
- rate limit: `ip_address`(= `request.remoteAddr`, 기존 관례) 기준 최근 60분 내 `dutypark.inquiry.rate-limit.max-per-hour`(기본 5) 이상이면 `RateLimitException("inquiry.rateLimit.exceeded")` → 429. 설정 클래스 `InquiryRateLimitConfig`(`@ConfigurationProperties("dutypark.inquiry.rate-limit")`), `application.yml`에 기본값 추가.
- `@SlackNotification` 부착.

### 3.5 관리자 — `/admin/api/**`

#### 신고 (`AdminReportController`, `/admin/api/reports`) — BE-3

| Method | Path | 요청 | 응답 |
|---|---|---|---|
| `GET` | `/admin/api/reports?status=OPEN&page&size` | `status` 생략/`ALL`이면 전체 | `PageResponse<AdminReportSummaryDto>` (created_date desc) |
| `GET` | `/admin/api/reports/{id}` | — | `AdminReportDetailDto` |
| `PATCH` | `/admin/api/reports/{id}/status` | `{ status: RESOLVED\|DISMISSED, memo?: String }` | `200 AdminReportDetailDto` (`resolved_at/by` 기록) |
| `DELETE` | `/admin/api/reports/{id}/target` | — | `200 AdminReportDetailDto`. `MEMBER` 대상이면 `400 report.target.notDeletable`; 이미 없으면 `200`(멱등) |

```kotlin
data class AdminReportSummaryDto(
    val id: UUID, val targetType: ReportTargetType, val targetId: String,
    val reason: ReportReason, val status: ReportStatus, val createdAt: LocalDateTime,
    val reporter: ReportPartyDto?, val reportedMember: ReportPartyDto?,   // null = 탈퇴
    val reporterName: String, val reportedMemberName: String,          // 스냅샷
    val snapshotPreview: String,                                       // content_snapshot 첫 줄 ≤100자
)
data class ReportPartyDto(val id: Long, val name: String, val status: MemberStatus)
data class AdminReportDetailDto(
    /* Summary 전체 필드 + */ val detail: String?, val contentSnapshot: String,
    val targetExists: Boolean, val adminMemo: String?, val resolvedAt: LocalDateTime?, val resolvedByName: String?,
)
```

콘텐츠 삭제 구현: `ScheduleService.deleteSchedule(loginMember, id)`의 첨부·디렉터리·엔티티 삭제 부분을 `internal fun deleteScheduleInternal(schedule: Schedule)`로 추출하고 기존 메서드는 권한 검사 후 이를 호출. `TodoService.deleteTodo`도 동일하게 `deleteTodoInternal(todo)` 추출(첨부는 `attachmentRepository.findAllByContextTypeAndContextId(TODO, id)` + `attachmentService.deleteAttachment(attachment: Attachment)`(:130 오버로드) 사용해 `LoginMember` 의존 제거). Todo는 현재 컨텍스트 디렉터리를 지우지 않는데(일정과 다름), 이 비대칭은 **의도적으로 유지**한다(동작 변경 금지). 관리자 서비스는 internal 메서드만 호출.

#### 계정 정지 (`AdminController` 확장) — BE-3

| Method | Path | 응답 |
|---|---|---|
| `POST` | `/admin/api/members/{memberId}/suspension` | `200`. `member.suspend()` + `refreshTokenService.revokeAllRefreshTokensByMember(member)`. 이미 정지면 멱등 `200`. `DELETION_PENDING`이면 `409 member.suspend.deletionPending` — 공용 409 예외 클래스가 없으므로 `AccountDeletionException(code, 409)` 패턴을 따라 `member/exception/MemberSuspensionException(message, errorCode = 409)`를 새로 만든다 |
| `DELETE` | `/admin/api/members/{memberId}/suspension` | `200`. `member.reinstate()`. 정지 상태가 아니면 멱등 `200` |

`AdminMemberDto`, `AdminMemberDetailDto`에 `status: MemberStatus` 필드 추가.

`AuthService.ensureActive` ([AuthService.kt:253](../../src/main/kotlin/com/tistory/shanepark/dutypark/security/service/AuthService.kt))를 `SUSPENDED`면 `AuthException("auth.account.suspended")`, 그 외 비활성은 기존 `code` 유지로 분기. 비밀번호 로그인 경로([AuthService.kt:112](../../src/main/kotlin/com/tistory/shanepark/dutypark/security/service/AuthService.kt))는 비밀번호 검증 **성공 후** `ensureActive`를 호출해 정지 계정에 `auth.account.suspended`가 노출되게 한다(비밀번호가 틀리면 여전히 `LOGIN_FAILED`). 나머지 `== ACTIVE` 비교 지점(ReauthService, AppleNativeOAuthService 등)은 그대로 두어도 정지 계정을 거부한다 — 변경하지 않는다.

#### 문의 (`AdminInquiryController`, `/admin/api/inquiries`) — BE-4

| Method | Path | 요청 | 응답 |
|---|---|---|---|
| `GET` | `/admin/api/inquiries?status=OPEN&page&size` | `status` 생략/`ALL`이면 전체 | `PageResponse<AdminInquiryDto>` |
| `GET` | `/admin/api/inquiries/{id}` | — | `AdminInquiryDto` |
| `PATCH` | `/admin/api/inquiries/{id}/status` | `{ status: OPEN\|CLOSED, memo?: String }` | `200 AdminInquiryDto` |

```kotlin
data class AdminInquiryDto(
    val id: UUID, val memberId: Long?, val memberName: String?, val email: String,
    val subject: String?, val content: String, val status: InquiryStatus,
    val adminMemo: String?, val createdAt: LocalDateTime, val closedAt: LocalDateTime?,
)
```

### 3.6 신규 에러 코드(클라이언트 i18n 필수)

| 코드 | HTTP | 의미 |
|---|---|---|
| `block.self` | 400 | 자기 자신 차단 |
| `friend.request.blocked` | 400 | 차단 관계에서 친구/가족 요청 |
| `report.self` | 400 | 자기 콘텐츠 신고 |
| `report.detail.required` | 400 | `OTHER`인데 상세 없음 |
| `report.target.notDeletable` | 400 | 관리자: MEMBER 대상 삭제 시도 |
| `member.suspend.deletionPending` | 409 | 삭제 대기 계정 정지 시도 |
| `auth.account.suspended` | 401 | 정지된 계정 로그인/갱신 |
| `inquiry.rateLimit.exceeded` | 429 | 문의 과다 |

---

## 4. 클라이언트 동작 명세 (웹·iOS 공통)

### 4.1 차단

- **진입점 A — 타인 달력 헤더 `⋯` 메뉴** (로그인 + `!isMyCalendar`): 항목 `사용자 신고`, `사용자 차단`. 차단 → 확인 다이얼로그("차단하면 친구 관계가 해제되고 서로의 달력·검색·요청·알림이 차단됩니다. 같은 팀 근무표는 계속 표시됩니다.") → `POST /api/blocks/{id}` → 성공 토스트 → **이전 화면으로 이동**(차단 직후 열람이 401이 되므로).
- **진입점 B — 친구 카드 케밥 메뉴**: `언프렌드` 아래 `차단`. 확인 → 차단 → 친구 목록 새로고침.
- **차단 목록**: 친구 관리 화면 하단 "차단한 사용자 (N)" 섹션. 항상 렌더(0건이면 빈 상태 문구 "차단한 사용자가 없습니다"). 각 행: 아바타·이름·차단일·`차단 해제` 버튼(확인 없이 즉시, 멱등).
- 게스트에게는 차단 메뉴를 보이지 않는다.

### 4.2 신고

- **신고 폼(공용 컴포넌트)**: 대상 라벨(예: "일정: {제목}" / "사용자: {이름}"), 사유 라디오/피커 5종, 상세 텍스트(≤500, `OTHER` 선택 시 필수 표시), 체크박스 "이 사용자도 차단"(대상 소유자가 본인이면 폼 자체를 열지 않음), 제출. 성공 시 "신고가 접수되었습니다. 24시간 이내에 확인합니다." 토스트. 200(중복)도 성공으로 처리.
- **진입점**
  1. 타인 달력 헤더 `⋯` → `사용자 신고` (`MEMBER`)
  2. 일정 행 액션 영역 → 깃발 아이콘 `신고` (`SCHEDULE`). 표시 조건: 로그인 && (`!isMyCalendar` || `schedule.isTagged`)
  3. Todo 상세 모달 푸터 → `신고` (`TODO`). 표시 조건: 로그인 && (`!isMyCalendar` || 태그된 Todo)
- **게스트(비로그인) 공개 달력**: 헤더 `⋯` 메뉴에 `신고`만 노출. 누르면 "신고하려면 로그인이 필요합니다" 확인 → 로그인 화면으로 이동(웹: `router.push(buildLoginRoute(route.fullPath))`, iOS: `GuestRoute.login`). 게스트에겐 일정/Todo 단위 신고 버튼을 보이지 않는다(로그인 후 전체 진입점 사용).

### 4.3 문의(지원)

- **웹 `/support`(공개, `requiresAuth: false`)**: (1) 안내 — 신고·차단 방법, 처리 기준(접수 후 24시간 이내 확인·조치, 정지 이의제기는 이 양식으로), 이용약관 링크; (2) 문의 양식 — 이메일(로그인 시 계정 이메일 프리필, 수정 가능), 제목(선택), 내용, 제출 → 완료 안내. 429 시 "잠시 후 다시 시도" 안내.
- **웹 링크 위치**: 더보기 메뉴(앱 그룹, `guide` 옆 `support`), 로그인 화면 하단(약관·개인정보 버튼 옆 `문의` 링크).
- **iOS**: 로그인 사용자 — 더보기 `MoreMenuItem.support` → `SupportView`(안내 + 양식, 계정 이메일 프리필). 게스트 — `GuestRootView`의 로그인 CTA 근처에 `문의하기` → 같은 `SupportView`(이메일 직접 입력).
- App Store Connect Support URL: `https://dutypark.o-r.kr/support`.

### 4.4 정지된 계정의 클라이언트 경험

로그인/자동 갱신 시 `auth.account.suspended` → "계정이 이용 정지되었습니다. 이의제기는 문의 페이지를 이용해 주세요." 웹은 `/support` 링크, iOS는 `SupportView`로 이동 가능하면 링크, 아니면 문구만. 기존 401 처리(로그아웃 → 로그인 화면)에 메시지만 얹는다 — 새 화면을 만들지 않는다.

---

## 5. 작업 패키지 (WP)

각 WP는 단일 소유자. **굵은 파일은 그 WP만 수정한다.** 다른 WP가 같은 파일을 만져야 하면 이 문서를 먼저 고친다.

### 의존 관계와 순서

```
BE-1 (block)  ──┐
                ├─→ BE-2 (report, alsoBlock가 BlockService 사용)
BE-3 (admin reports/suspend)   BE-4 (inquiry)   BE-5 (terms)      ← 서로 독립, BE-1과도 독립
WEB-1..4, IOS-1..3            ← §3 계약만 보고 백엔드와 동시 진행 가능. 통합 검증은 백엔드 머지 후
FINAL (release note, readiness 문서, 통합 검증)
```

권장 라운드: **R1** = BE-1 · BE-3 · BE-4 · BE-5 · WEB-1 · WEB-3 · WEB-4 · IOS-1 · IOS-3 (9개 병렬) → **R2** = BE-2 · WEB-2 · IOS-2 (신고; BE-2는 BE-1 머지 후, WEB-2/IOS-2는 R1과 동시 시작 가능하나 파일 충돌 없음 확인) → **FINAL**.

각 WP는 `isolation: worktree`로 실행하고, 머지 시 메인 에이전트가 i18n 파일 충돌을 정리한다.

---

### BE-1 · 차단 도메인 + 강제 지점

- **신규**: `member/block/domain/entity/MemberBlock.kt`, `member/block/repository/MemberBlockRepository.kt`, `member/block/service/BlockService.kt`, `member/block/controller/BlockController.kt`, `member/block/domain/dto/BlockedMemberDto.kt`, **`db/migration/v2/V2.2.38__member_block.sql`**
- **수정**: **`FriendService.kt`**(isVisible·sendFriendRequest·sendFamilyRequest), **`MemberRepository.kt`**(searchPossibleFriends), **`NotificationEventListener.kt`**
- 테스트(RED 먼저): `BlockServiceIntegrationTest`(멱등, 언프렌드·가족·pending 삭제, 양방향), `BlockControllerTest`(RestDocs), `FriendServiceIntegrationTest`에 케이스 추가(차단 시 isVisible false / 같은 팀이면 true / 검색 제외 / 요청 400), `NotificationEventListener` 차단 skip 테스트, 기존 `AccountDeletion*` 테스트 통과 확인
- 검증: `./gradlew test --tests "*Block*" --tests "*FriendService*" --tests "*Notification*" --tests "*AccountDeletion*"` → 이후 전체 `./gradlew test`

### BE-2 · 신고 도메인 (BE-1 이후)

- **신규**: `report/domain/entity/ContentReport.kt`, `report/domain/enums/{ReportTargetType,ReportReason,ReportStatus}.kt`, `report/repository/ContentReportRepository.kt`, `report/service/ReportService.kt`(스냅샷 조립 포함, `@SlackNotification`), `report/controller/ReportController.kt`, `report/domain/dto/CreateReportRequest.kt`, **`V2.2.39__content_report.sql`**
- 수정 없음(Schedule/Todo/Attachment 리포지토리 읽기만)
- 테스트: 대상별 스냅샷, 자기 신고 400, OTHER 상세 필수, 중복 OPEN → 200 동일 id, alsoBlock → 차단·언프렌드 확인, 404, RestDocs
- 검증: `./gradlew test --tests "*Report*"`

### BE-3 · 관리자 신고 처리 + 콘텐츠 삭제 + 계정 정지

- **신규**: `report/controller/AdminReportController.kt`, `report/service/AdminReportService.kt`, `report/domain/dto/AdminReport*Dto.kt`
- **수정**: **`MemberStatus.kt`**, **`Member.kt`**(suspend/reinstate), **`AdminController.kt`**(suspension 엔드포인트), **`AdminService.kt`/`AdminMemberDto`/`AdminMemberDetailDto`**(status), **`AuthService.kt`**(ensureActive 분기, 비밀번호 로그인 순서), **`ScheduleService.kt`**(`deleteScheduleInternal` 추출), **`TodoService.kt`**(`deleteTodoInternal` 추출)
- BE-2와의 접점: `ContentReport` 엔티티/리포지토리는 BE-2 소유. BE-3는 BE-2 머지 후 시작하거나, R1에서 정지·삭제 internal 추출 부분만 먼저 하고 신고 관리 컨트롤러는 BE-2 머지 후 추가한다(권장: 2단계로 분할, 같은 소유자)
- 테스트: 정지 → 로그인/refresh/impersonate 거부(`auth.account.suspended`), 세션 폐기, 해제, DELETION_PENDING 409; 신고 목록 필터·상세·상태 변경·대상 삭제(일정 첨부 디렉터리까지 삭제, MEMBER 400, 이미 삭제 멱등); 기존 `ScheduleServiceTest`/`TodoServiceTest` 삭제 케이스 회귀
- 검증: `./gradlew test --tests "*Admin*" --tests "*AuthService*" --tests "*ScheduleService*" --tests "*TodoService*"`

### BE-4 · 문의 도메인 + rate limit + 관리자 문의 API

- **신규**: `inquiry/domain/entity/Inquiry.kt`, `inquiry/domain/enums/InquiryStatus.kt`, `inquiry/repository/InquiryRepository.kt`, `inquiry/service/InquiryService.kt`(`@SlackNotification`), `inquiry/controller/InquiryController.kt`, `inquiry/controller/AdminInquiryController.kt`, `inquiry/config/InquiryRateLimitConfig.kt`, dto, **`V2.2.40__inquiry.sql`**
- **수정**: **`application.yml`**(`dutypark.inquiry.rate-limit.max-per-hour: 5`), `src/test/resources/application.yml`(동일 키)
- 테스트: 로그인/비로그인 생성, 이메일 형식 검증, IP 6번째 429, 관리자 목록 필터·상태 변경, RestDocs
- 검증: `./gradlew test --tests "*Inquiry*"`

### BE-5 · 이용약관 새 버전 발행

- **신규**: **`V2.2.41__publish_terms_with_community_guidelines.sql`** — `V2.2.36`의 TERMS 본문을 복사한 뒤 아래 조항을 추가한 새 버전 INSERT(`version` = `effective_date` = 배포 예정일, 형식 `YYYY-MM-DD`; 마이그레이션 작성 시점 날짜를 쓰고 FINAL에서 배포일과 맞춘다). 기존 행 수정 금지.
- 추가 조항(초안 항목 — 문구는 기존 약관 톤에 맞춰 작성):
  - **금지 콘텐츠**: 타인 비방·괴롭힘·혐오, 음란·폭력, 스팸·광고, 사칭, 불법 정보, 타인 개인정보
  - **신고와 차단**: 앱 내 신고 기능, 사용자 차단 기능과 그 효과(친구 관계 해제, 열람·검색·요청·알림 차단, 팀 근무표는 유지)
  - **운영 조치와 제재 단계**: 신고 접수 후 **24시간 이내 확인·조치**, 단계 = 경고 → 콘텐츠 삭제 → 계정 이용 정지 → 계약 해지, 긴급·중대 위반은 단계 생략 가능
  - **이의제기**: 문의 페이지(`/support`)로 접수, 접수 후 처리 기준
  - **연락처**: 문의 페이지 URL
- 검증: `V2.2.36`의 짝 테스트 `policy/migration/ProviderNeutralTermsAndAiPolicyMigrationTest.kt`를 본떠 새 마이그레이션 테스트 작성(새 버전이 current TERMS로 조회되고 필수 조항 문구를 포함), `./gradlew test --tests "*Policy*"`

---

### WEB-1 · FriendsView 리팩토링 + 차단 목록 + 케밥 차단

- **신규**: `frontend/src/api/block.ts`(`blockApi.block/unblock/getBlockedMembers`), `frontend/src/components/member/FriendRequestList.vue`, `FriendCard.vue`, `FriendActionMenu.vue`(Teleport 케밥 — 기존 `:684-737` 추출, `block` 항목 추가), `BlockedMemberList.vue`, `frontend/src/types/block.ts`
- **수정**: **`frontend/src/views/member/FriendsView.vue`**(추출 후 조립 + 차단 섹션), **`frontend/src/i18n/messages/{ko,en}.ts`의 `friends:` 네임스페이스**(차단 관련 키를 `friends.block.*`로 추가)
- 지켜야 할 기존 테스트: `views/more/moreMenu.test.ts`(FriendsView의 `<PageHeader … show-back back-fallback="/more">` 유지). Sortable은 `FriendCard` 루트에 `data-member-id` 유지
- 테스트: `FriendsView`/`FriendActionMenu` `?raw` 소스 검증(차단 항목·확인 다이얼로그 존재), `block.ts` 유닛(선택)
- 검증: `npm run type-check && npm run build && npx vitest run`

### WEB-2 · 신고 모달 + 진입점 + 헤더 `⋯` 메뉴 + 게스트 로그인 유도

- **신규**: `frontend/src/api/report.ts`, `frontend/src/types/report.ts`, `frontend/src/components/common/ReportModal.vue`(BaseModal 기반, §4.2 폼), `frontend/src/components/common/OverflowMenu.vue`(선택 — WEB-1의 `FriendActionMenu`와 겹치지 않게 헤더 전용 단순 메뉴; 재사용이 쉬우면 WEB-1 산출물 사용)
- **수정**: **`components/duty/DutyHeaderControls.vue`**(우측 `⋯` 버튼 + `report-member`/`block-member` emit; `showOverflow` prop), **`components/duty/ScheduleList.vue`**(신고 버튼 + `report` emit), **`components/duty/TodoDetailModal.vue`**(신고 버튼 + `report` emit — 기존 `TodoDetailModal.test.ts` 푸터 클래스 정규식 유지), **`components/duty/DayDetailModal.vue`**(emit 전달), **`views/duty/DutyView.vue`**(모달 상태, `requireLogin()` 헬퍼, 차단 후 `router.back()`), **`i18n/messages/{ko,en}.ts`의 `report:` 신규 네임스페이스 + `apiErrors` 신규 코드 전부**(§3.6의 8개 — 다른 WEB 작업은 `apiErrors`를 건드리지 않는다)
- 테스트: `ReportModal`/`DutyView` `?raw` 검증(게스트 분기, alsoBlock), 기존 `TodoDetailModal.test.ts` 통과
- 검증: `npm run type-check && npm run build && npx vitest run`

### WEB-3 · 관리자 신고·문의 페이지 + 정지 버튼

- **신규**: `frontend/src/views/admin/AdminReportListView.vue`, `AdminInquiryListView.vue`, `frontend/src/components/admin/AdminReportDetailModal.vue`, `AdminInquiryDetailModal.vue`, `frontend/src/types/admin*.ts` 확장 파일
- **수정**: **`frontend/src/api/admin.ts`**(기존 헤더 스타일 `// ========== Report Management ==========`, `// ========== Inquiry Management ==========`, `suspendMember/unsuspendMember`), **`views/admin/AdminDashboardView.vue`**(상단 타일에 `/admin/reports`, `/admin/inquiries` 링크 — 기존 `/admin/teams` 타일 패턴; 미처리 건수는 `getReports('OPEN', 0, 1).totalElements`로 표시), **`components/admin/AdminMemberDetailModal.vue`**(status 배지 + 정지/해제 버튼 emit), **`i18n/messages/{ko,en}.ts`의 `admin:` 네임스페이스**
- 라우트 등록은 WEB-4가 한다(경로: `/admin/reports`, `/admin/inquiries`, `requiresAuth + requiresAdmin`)
- 목록 UI: `AdminDashboardView`의 카드-행 + 페이지네이션 패턴, 상태 필터 탭(OPEN 기본 / RESOLVED / DISMISSED / ALL). 상세 모달 액션: 상태 변경(메모), 콘텐츠 삭제(confirmDelete), 피신고자 정지/해제, "달력 보기"(`/duty/{reportedMemberId}`)
- 검증: `npm run type-check && npm run build && npx vitest run`

### WEB-4 · `/support` 페이지 + 라우트·메뉴 등록

- **신규**: `frontend/src/views/support/SupportView.vue`(안내 + 문의 양식; `TermsView.vue` 카드 레이아웃 참고. **`moreMenu.test.ts`의 "more sub-page back navigation" 규칙 때문에 `<PageHeader … show-back back-fallback="/more">`를 반드시 사용**하고 테스트의 `PAGE_HEADER_VIEWS`에 `?raw` import를 추가한다), `frontend/src/api/inquiry.ts`, `frontend/src/types/inquiry.ts`
- **수정**: **`frontend/src/router/routes.ts`**(`/support` public, `/admin/reports`, `/admin/inquiries` admin), **`views/more/moreMenu.ts`**(`support` 항목, `MORE_MENU_PATHS`) + **`moreMenu.test.ts`**(id·경로·그룹 길이·`?raw` 목록 갱신), **`views/auth/LoginView.vue`**(약관·개인정보 옆 `/support` 링크 — `router/backNavigation.test.ts` 통과 유지), **`i18n/messages/{ko,en}.ts`의 `support:` 신규 네임스페이스 + `header.menu.support` 라벨 키**
- 검증: `npm run type-check && npm run build && npx vitest run`

---

### IOS-1 · SocialView 리팩토링 + 차단 목록 + 팝오버 차단

- **신규**: `Features/Social/FriendSearchModalView.swift`(기존 `:999-1266` 이동), `Features/Social/FriendActionPopover.swift`(`:921-997` 이동 + `onBlock` 클로저), `Features/Social/SocialConfirmation.swift`(`:1338-1396` 이동 + `.block(friend)` 케이스), `Features/Social/BlockedMembersPanel.swift`, `Domain/Models/BlockModels.swift`(`BlockedMemberDTO`)
- **수정**: **`Features/Social/SocialView.swift`**(조립 + 하단 차단 섹션; **`SocialFeatureTests.swift:9-24`가 검사하는 문자열 `.fullScreenCover(item: $confirmation)`, `DPConfirmationPanel(`, `canDismiss: !isPerformingConfirmation`, `isWorking: isPerformingConfirmation`, `isDestructive: true`, `.alert(item: $candidate)`는 SocialView.swift 본문에 남기고, `.alert(item: $confirmation)`은 절대 쓰지 않는다(부정 assertion 있음)**), **`Features/Social/SocialRepository.swift`**(`block/unblock/blockedMembers`), **`Features/Social/SocialViewModel.swift`**, **`Resources/Social.xcstrings`**
- 테스트: `SocialFeatureTests`에 ViewModel+Spy 케이스(차단 → 목록 갱신·해제), 기존 Social 유닛/UI 테스트 전부 통과(드래그·핀 UI 테스트 id 유지)
- 검증: `ios/README.md`의 build + test 명령

### IOS-2 · 신고 시트 + 진입점 + 달력 `⋯` 메뉴 + 게스트 로그인 유도

- **신규**: `Features/Report/ReportSheet.swift`(DPModalPanel + reason Picker + TextEditor + Toggle; Todo 폼 `TodoView.swift:1452-1495` 참고), `Features/Report/ReportRepository.swift`, `Features/Report/ReportViewModel.swift`, `Features/Report/Report.xcstrings`(feature-local — `LocalizationCatalogTests.expectedCatalogNames`에 넣지 않음), `Domain/Models/ReportModels.swift`
- **수정**: **`Features/Calendar/CalendarView.swift`**(`calendarToolbar`(:261-282) trailing HStack에 `Menu` — `isPushedMemberCalendar && !model.isMyCalendar`일 때 `사용자 신고`/`사용자 차단`. 주의: trailing 영역은 `.frame(width: Self.barSideWidth)` 고정폭에 이미 컨트롤 2개가 있어 클리핑 위험 — 폭을 늘리거나 `thisMonthControl`을 메뉴 안으로 옮기는 식으로 처리하고 UI 테스트로 확인; `scheduleCard`(:1859)의 액션 분기는 `if isTagged … else if model.canEdit` 구조라 **신고는 별도 분기/버튼으로 추가**(조건 §4.2: 로그인 && (`!model.isMyCalendar` || isTagged), 44pt); 차단 후 `memberBackAction`(:288)), **`Features/Calendar/Calendar.xcstrings`**, **`Features/Todo/TodoModalViews.swift`**(`TodoDetailModal` 신고 액션) + **`Features/Todo/Todo.xcstrings`**, **`Features/Guest/GuestPublicCalendarView.swift`**(툴바 `⋯` → 신고 → 확인 → `GuestRoute.login`) + **`Features/Guest/Guest.xcstrings`**, **`Resources/Errors.xcstrings`**(§3.6 8개 코드 전부 — IOS-1/IOS-3는 Errors.xcstrings를 건드리지 않는다), 차단 API는 IOS-1의 `SocialRepository`를 쓰지 않고 `ReportRepository`에 `block(memberID:)`를 별도로 둔다(파일 충돌 회피; 경로 동일 `/api/blocks/{id}`)
- 테스트: `ReportViewModel` + mock repository(OTHER 상세 필수, alsoBlock, 중복 200 성공 처리), Calendar/Guest 소스 텍스트 검사(메뉴 존재), `Report.xcstrings`/`Calendar.xcstrings` 신규 키 en·ko 파리티 스팟 테스트(`CalendarFeatureTests.swift:108-120` 패턴)
- 검증: build + test

### IOS-3 · 문의(SupportView) + 더보기·게스트 진입 + 정지 메시지

- **신규**: `Features/Support/SupportView.swift`(안내 + 양식, `prefilledEmail: String?`), `Features/Support/SupportRepository.swift`, `Features/Support/SupportViewModel.swift`, `Features/Support/Support.xcstrings`, `Domain/Models/InquiryModels.swift`
- **수정**: **`Features/More/MoreView.swift`**(`MoreMenuItem.support` — 그룹 2 `guide` 옆; `systemImage`/`title`/`accessibilityIdentifier`), **`App/RootTabView.swift`**(`moreDestination(for: .support)`), **`Resources/Localizable.xcstrings`**(더보기 라벨), **`Features/Guest/GuestRootView.swift`**(로그인 CTA 근처 `문의하기` → `SupportView`; Guest.xcstrings는 IOS-2 소유이므로 문구 키는 `Support.xcstrings`에 둔다), 로그인 화면의 `auth.account.suspended` 처리는 Errors 테이블 번역(IOS-2)만으로 표시되면 추가 변경 없음
- 테스트: `SupportViewModel` + mock(이메일 검증, 429 처리), More 메뉴 기존 테스트 갱신 — `DutyparkTests/RootChromeLocalizationTests.swift`(`visibleItems` :30/:37, `visibleGroups` :45)와 `AppLanguageOverrideLocalizationTests.swift:40`(모든 `MoreMenuItem.title`의 ko·en 존재)
- 검증: build + test

---

### FINAL · 통합 (메인 에이전트)

1. 머지 순서: BE-1 → BE-2 → BE-3 → BE-4 → BE-5 → WEB-1..4 → IOS-1..3. i18n(`ko.ts`/`en.ts`, xcstrings) 충돌은 네임스페이스별로 기계적으로 병합.
2. 전체 검증: `./gradlew test` / `npm run type-check && npm run build && npx vitest run` / iOS build + test → **`iPhone 13 mini` 시뮬레이터에 설치**.
3. 수동 E2E(개발 DB `dutypark_dev_db`): 계정 A·B로 (a) B가 A 신고+차단 → A는 B 검색·요청·달력 불가, B 친구 목록에서 A 사라짐, 차단 목록에 A → 해제, (b) 관리자가 신고 상세 → 콘텐츠 삭제 → 상태 RESOLVED, (c) 관리자가 A 정지 → A 로그인 시 `auth.account.suspended` → 해제, (d) 게스트가 `/support` 문의 작성 → 관리자 문의 목록, (e) 게스트 공개 달력 신고 → 로그인 → 복귀.
4. PR 생성 → 실제 PR 번호로 릴리스 노트 1건(`src/main/resources/public-content/release-notes.json`, ko/en, `npm run release-notes:check`).
5. [ios/app-store-readiness/README.md](../../ios/app-store-readiness/README.md) §1 체크 갱신, §3 "신고·차단 기능을 사실대로 선언" 항목에 답 기록, Support URL 기입 항목 추가.
6. TERMS 마이그레이션의 `effective_date`를 배포일과 맞춘다(필요 시 **새** 마이그레이션으로 — 기존 파일 수정 금지).

---

## 6. i18n 키 소유권 (충돌 방지)

| 파일 | 네임스페이스/영역 | 소유 |
|---|---|---|
| `frontend/src/i18n/messages/{ko,en}.ts` | `friends.block.*` | WEB-1 |
| 〃 | `report.*`, `apiErrors` 신규 8개(`apiErrors`는 네임스페이스가 아니라 `ko.ts:1`/`en.ts:1`의 최상위 `const apiErrors = {…}` — 파일 상단을 편집) | WEB-2 |
| 〃 | `admin.reports.*`, `admin.inquiries.*`, `admin.memberDetail.suspend*` | WEB-3 |
| 〃 | `support.*`, `header.menu.support`(더보기 라벨은 `header.menu.*`에 있음 — `moreMenu.ts`의 `labelKey` 참고) | WEB-4 |
| `ios/Dutypark/Resources/Social.xcstrings` | 차단 관련 | IOS-1 |
| `Resources/Errors.xcstrings` | 신규 8개 코드 | IOS-2 |
| `Features/Calendar/Calendar.xcstrings`, `Features/Todo/Todo.xcstrings`, `Features/Guest/Guest.xcstrings`, 신규 `Features/Report/Report.xcstrings` | 신고·헤더 메뉴·게스트 유도 | IOS-2 |
| 신규 `Features/Support/Support.xcstrings`, `Resources/Localizable.xcstrings`(더보기 라벨) | 문의 | IOS-3 |

`Resources/*.xcstrings`에 **새 파일을 만들지 않는다**(`LocalizationCatalogTests.expectedCatalogNames` 고정). 신규 카탈로그는 모두 feature-local.

---

## 7. 검증 매트릭스

| 계층 | 명령 | 통과 기준 |
|---|---|---|
| 백엔드(WP별) | `./gradlew test --tests "<패턴>"` | 신규 테스트 RED→GREEN, 관련 기존 테스트 GREEN |
| 백엔드(FINAL) | `./gradlew test` | 전부 GREEN. 실패가 있으면 이 변경 기인 여부 구분해 보고 |
| 웹 | `npm run type-check && npm run build && npx vitest run` | 에러 0. `moreMenu.test.ts`, `TodoDetailModal.test.ts`, `memberSettingsSplit.test.ts`, `backNavigation.test.ts` 유지 |
| iOS | `ios/README.md` build + test 명령 | 빌드 성공, `DutyparkTests` 전부 GREEN(`LocalizationCatalogTests`, `SocialFeatureTests`, `CalendarFeatureTests` 포함) |
| 시뮬레이터 | `iPhone 13 mini` 설치 | 설치 성공 또는 정확한 실패 사유 보고 |
| 수동 E2E | §5 FINAL 3항 | 5개 시나리오 재현 |

---

## 8. App Review 제출물 (코드 외)

**Review Notes 초안(영문)** — App Store Connect에 붙여넣을 재현 경로:

> Dutypark is a duty-roster/calendar app shared with friends, family and teammates. User content (schedules, to-dos, profile photo) is visible only to friends/family/team or, if the owner opts in, publicly.
> - **Report**: open any other member's calendar → "⋯" (top-right) → "Report user"; or tap the flag icon on a schedule row / "Report" in a to-do detail. Choose a reason, optionally add details, optionally tick "Also block this user". Reports are reviewed within 24 hours by the operator (Slack alert on submission), who can delete the content, dismiss, or suspend the account (Admin → Reports).
> - **Block**: Friends → "⋯" on a friend card → "Block", or from the member calendar "⋯" menu. Blocking removes the friendship, hides both calendars from each other, removes each other from search, and rejects friend requests and notifications. Manage at Friends → "Blocked users" → "Unblock".
> - **Contact**: Support page https://dutypark.o-r.kr/support (no login required) and in-app More → Support (iOS). Inquiries are answered by e-mail.
> - **Terms** (prohibited content, sanctions, appeals): https://dutypark.o-r.kr/terms
> - Test accounts: reviewer account A (friend of B) and account B — see credentials field. To test moderation, submit a report from A; the admin queue is web-only at https://dutypark.o-r.kr/admin/reports (admin credentials in the credentials field).

App Store Connect 입력: Support URL = `https://dutypark.o-r.kr/support`, 신고·차단 기능 "있음"으로 선언, 심사용 계정 2개(친구 관계 미리 설정) + 관리자 계정 1개.

---

## 9. 리스크와 대응

| 리스크 | 대응 |
|---|---|
| Apple이 "필터링" 부재를 지적 | 서버 금칙어 필터(일정 content/description, Todo title/content, 회원 이름)를 후속 WP로 즉시 추가할 수 있게 `ReportService`/검증 위치를 분리해 둔다. 이 문서 §1 D4에 후속 조건 기록 |
| `isVisible`이 `memberRepository.findById`를 매 호출 수행 — 차단 조회 추가로 쿼리 +1 | 인덱스(uk + blocked_id) 있으므로 허용. 성능 이슈 시 캐시 검토(비목표) |
| 같은 팀원 차단 시 사용자가 "왜 아직 보이지?" 혼란 | 차단 확인 다이얼로그와 약관에 "같은 팀 근무표는 유지" 명시 |
| 계정 삭제 워커가 새 FK로 실패 | CASCADE/SET NULL로 설계. BE-1/2/4가 `AccountDeletion*` 테스트로 확인 |
| `remoteAddr` 기반 rate limit이 프록시 뒤에서 한 IP로 뭉침 | 기존 로그인 rate limit과 같은 한계. 운영에서 `X-Forwarded-For` 처리가 필요하면 별도 이슈(비목표) |
| 동시 세션이 `V2.2.38`을 먼저 사용 | 각 BE WP 시작 시 최신 버전 확인 후 오프셋 조정, 메인 에이전트에 보고 |
| iOS `SocialView`/웹 `FriendsView` 리팩토링이 UI 테스트를 깨뜨림 | 접근성 id·소스 문자열 assertion 목록을 WP에 명시(위). 리팩토링은 이동 위주, 동작 변경 금지 |
