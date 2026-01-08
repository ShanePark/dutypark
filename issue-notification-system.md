# Notification System Implementation Plan

## 1. Overview

### Purpose
사용자에게 친구 요청, 스케줄 태그 등 주요 이벤트를 알림으로 제공하는 시스템 구현

### Approach
- **Polling 기반**: 프론트엔드에서 주기적으로 미읽음 알림을 조회
- **이벤트 기반 생성**: 백엔드에서 도메인 이벤트 발생 시 알림 자동 생성
- **비동기 처리**: 알림 생성은 트랜잭션 완료 후 비동기로 처리

### Scope
- MVP: 친구 요청 관련 알림, 스케줄 태그 알림
- 향후 확장: 알림 설정, 푸시 알림, SSE 업그레이드

---

## 2. Database Schema

### Table: `notifications`

```sql
CREATE TABLE notifications (
    id CHAR(26) PRIMARY KEY COMMENT 'ULID',
    member_id BIGINT NOT NULL COMMENT '수신자 ID',
    type VARCHAR(50) NOT NULL COMMENT '알림 유형',
    title VARCHAR(255) NOT NULL COMMENT '알림 제목',
    content TEXT COMMENT '알림 내용 (optional)',
    reference_type VARCHAR(50) COMMENT '참조 엔티티 타입',
    reference_id VARCHAR(50) COMMENT '참조 엔티티 ID',
    actor_id BIGINT COMMENT '행위자 ID (알림을 발생시킨 사람)',
    is_read BOOLEAN NOT NULL DEFAULT FALSE COMMENT '읽음 여부',
    created_date DATETIME NOT NULL,

    INDEX idx_notifications_member_unread (member_id, is_read, created_date DESC),
    INDEX idx_notifications_member_created (member_id, created_date DESC),
    CONSTRAINT fk_notifications_member FOREIGN KEY (member_id) REFERENCES member(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Migration File
- Path: `src/main/resources/db/migration/v2/V2.x.x__notification.sql`
- Version number: 다음 사용 가능한 버전 사용

---

## 3. Backend Implementation

### 3.1 Package Structure

```
src/main/kotlin/com/tistory/shanepark/dutypark/notification/
├── domain/
│   ├── entity/
│   │   └── Notification.kt
│   ├── enums/
│   │   ├── NotificationType.kt
│   │   └── NotificationReferenceType.kt
│   └── repository/
│       └── NotificationRepository.kt
├── dto/
│   ├── NotificationDto.kt
│   └── NotificationCountDto.kt
├── service/
│   └── NotificationService.kt
├── controller/
│   └── NotificationController.kt
└── event/
    ├── NotificationEvent.kt
    └── NotificationEventListener.kt
```

### 3.2 Enums

#### NotificationType
| Value | Description | Title Template |
|-------|-------------|----------------|
| `FRIEND_REQUEST_RECEIVED` | 친구 요청 수신 | "{actorName}님이 친구 요청을 보냈습니다" |
| `FRIEND_REQUEST_ACCEPTED` | 친구 요청 수락됨 | "{actorName}님이 친구 요청을 수락했습니다" |
| `FAMILY_REQUEST_RECEIVED` | 가족 요청 수신 | "{actorName}님이 가족 요청을 보냈습니다" |
| `FAMILY_REQUEST_ACCEPTED` | 가족 요청 수락됨 | "{actorName}님이 가족 요청을 수락했습니다" |
| `SCHEDULE_TAGGED` | 스케줄에 태그됨 | "{actorName}님이 스케줄에 태그했습니다" |

#### NotificationReferenceType
| Value | Description |
|-------|-------------|
| `FRIEND_REQUEST` | FriendRequest 엔티티 참조 |
| `SCHEDULE` | Schedule 엔티티 참조 |
| `MEMBER` | Member 엔티티 참조 |

### 3.3 Entity

#### Notification
```
Notification (ULID 기반 엔티티, EntityBase 확장)
├── id: String (ULID)
├── member: Member (수신자, @ManyToOne LAZY)
├── type: NotificationType
├── title: String (최대 255자)
├── content: String? (nullable)
├── referenceType: NotificationReferenceType?
├── referenceId: String?
├── actorId: Long? (행위자 Member ID)
├── isRead: Boolean (default: false)
└── createdDate: LocalDateTime (EntityBase에서 상속)
```

### 3.4 DTOs

#### NotificationDto (Response)
```
NotificationDto
├── id: String
├── type: String (NotificationType.name)
├── title: String
├── content: String?
├── referenceType: String?
├── referenceId: String?
├── actorId: Long?
├── actorName: String? (조회 시 JOIN으로 채움)
├── actorHasProfilePhoto: Boolean?
├── actorProfilePhotoVersion: Int?
├── isRead: Boolean
└── createdAt: LocalDateTime

companion object:
  fun of(notification: Notification, actor: Member?): NotificationDto
```

#### NotificationCountDto (Response)
```
NotificationCountDto
├── unreadCount: Int
└── totalCount: Int
```

### 3.5 Repository

#### NotificationRepository (JpaRepository)
```
Methods:
├── findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(memberId: Long): List<Notification>
├── findByMemberIdOrderByCreatedDateDesc(memberId: Long, pageable: Pageable): Page<Notification>
├── countByMemberIdAndIsReadFalse(memberId: Long): Int
├── countByMemberId(memberId: Long): Int
├── findByMemberIdAndId(memberId: Long, notificationId: String): Notification?
└── deleteByCreatedDateBefore(date: LocalDateTime): Int (배치 삭제용)
```

### 3.6 Service

#### NotificationService
```
Dependencies:
├── NotificationRepository
├── MemberRepository
└── ApplicationEventPublisher (선택적, 알림 생성 후 이벤트 발행 시)

Methods:

# 조회
├── getUnreadNotifications(memberId: Long): List<NotificationDto>
│   └── 미읽음 알림 목록 조회 (최대 50개)
│
├── getNotifications(memberId: Long, pageable: Pageable): PageResponse<NotificationDto>
│   └── 전체 알림 페이징 조회
│
├── getUnreadCount(memberId: Long): NotificationCountDto
│   └── 미읽음/전체 카운트 조회

# 상태 변경
├── markAsRead(memberId: Long, notificationId: String): NotificationDto
│   └── 단건 읽음 처리, 본인 알림만 가능
│
├── markAllAsRead(memberId: Long): Int
│   └── 전체 읽음 처리, 처리된 개수 반환

# 삭제
├── deleteNotification(memberId: Long, notificationId: String)
│   └── 단건 삭제, 본인 알림만 가능
│
├── deleteAllRead(memberId: Long): Int
│   └── 읽은 알림 전체 삭제

# 생성 (내부용, 이벤트 리스너에서 호출)
└── createNotification(
        memberId: Long,
        type: NotificationType,
        actorId: Long?,
        referenceType: NotificationReferenceType?,
        referenceId: String?,
        content: String?
    ): Notification
    └── 알림 생성, title은 type에서 자동 생성
```

### 3.7 Controller

#### NotificationController
```
Base Path: /api/notifications
Authentication: Required (@Login)

Endpoints:

GET /api/notifications
├── Description: 전체 알림 목록 조회 (페이징)
├── Query Params:
│   ├── page: Int (default: 0)
│   └── size: Int (default: 20, max: 50)
├── Response: PageResponse<NotificationDto>
└── Status: 200 OK

GET /api/notifications/unread
├── Description: 미읽음 알림 목록 조회 (최대 50개)
├── Response: List<NotificationDto>
└── Status: 200 OK

GET /api/notifications/count
├── Description: 알림 카운트 조회
├── Response: NotificationCountDto
└── Status: 200 OK

PATCH /api/notifications/{id}/read
├── Description: 단건 읽음 처리
├── Path Param: id (String, ULID)
├── Response: NotificationDto
└── Status: 200 OK, 404 Not Found

PATCH /api/notifications/read-all
├── Description: 전체 읽음 처리
├── Response: { "count": Int }
└── Status: 200 OK

DELETE /api/notifications/{id}
├── Description: 단건 삭제
├── Path Param: id (String, ULID)
└── Status: 204 No Content, 404 Not Found

DELETE /api/notifications/read
├── Description: 읽은 알림 전체 삭제
├── Response: { "count": Int }
└── Status: 200 OK
```

### 3.8 Event System

#### NotificationEvent (Data Class)
```
NotificationEvent
├── recipientId: Long (수신자)
├── type: NotificationType
├── actorId: Long? (행위자)
├── referenceType: NotificationReferenceType?
├── referenceId: String?
└── content: String?
```

#### NotificationEventListener
```
@Component
@TransactionalEventListener(phase = AFTER_COMMIT)
@Async("notificationExecutor")

Listens to:
├── FriendRequestSentEvent → FRIEND_REQUEST_RECEIVED
├── FriendRequestAcceptedEvent → FRIEND_REQUEST_ACCEPTED
├── FamilyRequestSentEvent → FAMILY_REQUEST_RECEIVED
├── FamilyRequestAcceptedEvent → FAMILY_REQUEST_ACCEPTED
└── ScheduleTaggedEvent → SCHEDULE_TAGGED
```

#### 도메인 이벤트 정의 (신규)

```
FriendRequestSentEvent
├── requestId: Long
├── fromMemberId: Long
└── toMemberId: Long

FriendRequestAcceptedEvent
├── requestId: Long
├── fromMemberId: Long
└── toMemberId: Long

FamilyRequestSentEvent
├── requestId: Long
├── fromMemberId: Long
└── toMemberId: Long

FamilyRequestAcceptedEvent
├── requestId: Long
├── fromMemberId: Long
└── toMemberId: Long

ScheduleTaggedEvent
├── scheduleId: String
├── ownerId: Long
└── taggedMemberId: Long
```

### 3.9 Service 수정 사항

#### FriendService
- `sendFriendRequest()`: `FriendRequestSentEvent` 발행 추가
- `acceptFriendRequest()`: `FriendRequestAcceptedEvent` 발행 추가
- `sendFamilyRequest()`: `FamilyRequestSentEvent` 발행 추가
- (가족 요청 수락 시): `FamilyRequestAcceptedEvent` 발행 추가

#### ScheduleService
- `tagFriend()`: `ScheduleTaggedEvent` 발행 추가
- 스케줄 생성 시 태그가 있으면 각 태그 멤버에게 이벤트 발행

### 3.10 Async Configuration

#### AsyncConfig 추가
```kotlin
@Bean(name = ["notificationExecutor"])
fun notificationExecutor(): Executor {
    return ThreadPoolTaskExecutor().apply {
        corePoolSize = 2
        maxPoolSize = 5
        queueCapacity = 100
        setThreadNamePrefix("notification-")
        initialize()
    }
}
```

### 3.11 Cleanup Scheduler

#### NotificationCleanupScheduler
```
@Scheduled(cron = "0 30 2 * * *") // 매일 새벽 2:30
@Transactional
fun cleanupOldNotifications()
└── 30일 이상 된 알림 삭제
└── 로그: "Deleted {} old notifications"
```

---

## 4. Frontend Implementation

### 4.1 File Structure

```
frontend/src/
├── api/
│   └── notification.ts
├── stores/
│   └── notification.ts
├── types/
│   └── index.ts (타입 추가)
├── components/
│   └── common/
│       ├── NotificationBell.vue
│       └── NotificationDropdown.vue
├── views/
│   └── notification/
│       └── NotificationListView.vue
└── router/
    └── index.ts (라우트 추가)
```

### 4.2 TypeScript Types

```typescript
// types/index.ts에 추가

export type NotificationType =
  | 'FRIEND_REQUEST_RECEIVED'
  | 'FRIEND_REQUEST_ACCEPTED'
  | 'FAMILY_REQUEST_RECEIVED'
  | 'FAMILY_REQUEST_ACCEPTED'
  | 'SCHEDULE_TAGGED'

export type NotificationReferenceType =
  | 'FRIEND_REQUEST'
  | 'SCHEDULE'
  | 'MEMBER'

export interface NotificationDto {
  id: string
  type: NotificationType
  title: string
  content: string | null
  referenceType: NotificationReferenceType | null
  referenceId: string | null
  actorId: number | null
  actorName: string | null
  actorHasProfilePhoto: boolean | null
  actorProfilePhotoVersion: number | null
  isRead: boolean
  createdAt: string
}

export interface NotificationCountDto {
  unreadCount: number
  totalCount: number
}
```

### 4.3 API Client

```typescript
// api/notification.ts

import apiClient from './client'
import type { NotificationDto, NotificationCountDto, PageResponse } from '@/types'

export const notificationApi = {
  // 전체 알림 조회 (페이징)
  getNotifications: (page = 0, size = 20) =>
    apiClient.get<PageResponse<NotificationDto>>('/notifications', {
      params: { page, size }
    }),

  // 미읽음 알림 조회
  getUnreadNotifications: () =>
    apiClient.get<NotificationDto[]>('/notifications/unread'),

  // 알림 카운트 조회
  getCount: () =>
    apiClient.get<NotificationCountDto>('/notifications/count'),

  // 단건 읽음 처리
  markAsRead: (id: string) =>
    apiClient.patch<NotificationDto>(`/notifications/${id}/read`),

  // 전체 읽음 처리
  markAllAsRead: () =>
    apiClient.patch<{ count: number }>('/notifications/read-all'),

  // 단건 삭제
  deleteNotification: (id: string) =>
    apiClient.delete(`/notifications/${id}`),

  // 읽은 알림 전체 삭제
  deleteAllRead: () =>
    apiClient.delete<{ count: number }>('/notifications/read')
}
```

### 4.4 Pinia Store

```typescript
// stores/notification.ts

State:
├── unreadNotifications: NotificationDto[]
├── unreadCount: number
├── isLoading: boolean
└── lastFetched: Date | null

Actions:
├── fetchUnreadCount(): Promise<void>
│   └── 미읽음 카운트만 조회 (폴링용, 가벼움)
│
├── fetchUnreadNotifications(): Promise<void>
│   └── 미읽음 알림 목록 조회
│
├── markAsRead(id: string): Promise<void>
│   └── 단건 읽음 처리 후 목록에서 제거
│
├── markAllAsRead(): Promise<void>
│   └── 전체 읽음 처리 후 목록 비우기
│
├── startPolling(intervalMs: number = 30000): void
│   └── 폴링 시작 (기본 30초)
│
└── stopPolling(): void
    └── 폴링 중지

Getters:
├── hasUnread: boolean
└── unreadCountDisplay: string (99+ 처리)
```

### 4.5 Components

#### NotificationBell.vue
```
위치: 헤더 우측
기능:
├── 미읽음 개수 뱃지 표시 (빨간 원, 99+)
├── 클릭 시 NotificationDropdown 토글
├── 마운트 시 폴링 시작
└── 언마운트 시 폴링 중지

Props: 없음
Emits: 없음
```

#### NotificationDropdown.vue
```
위치: NotificationBell 클릭 시 표시되는 드롭다운
기능:
├── 미읽음 알림 최대 10개 표시
├── 알림 클릭 시:
│   ├── 읽음 처리
│   └── referenceType에 따라 해당 페이지로 이동
│       ├── FRIEND_REQUEST → /member (친구 관리)
│       ├── SCHEDULE → /duty/{참조날짜}
│       └── MEMBER → /duty/{memberId}
├── "전체 읽음" 버튼
├── "더보기" 링크 → /notifications
└── 빈 상태 메시지

Props: 없음
Emits:
├── close: 드롭다운 닫기
└── navigate: 페이지 이동 시
```

#### NotificationListView.vue
```
경로: /notifications
기능:
├── 전체 알림 페이징 조회
├── 무한 스크롤 또는 페이지네이션
├── 읽음/안읽음 필터 (선택적)
├── 알림 클릭 → 읽음 처리 + 해당 페이지 이동
├── 개별 삭제 버튼
├── "읽은 알림 삭제" 버튼
└── 빈 상태 UI

라우트: /notifications (인증 필요)
```

### 4.6 AppHeader.vue 수정

```
변경 사항:
├── NotificationBell 컴포넌트 추가
├── 위치: 프로필 아이콘 좌측
└── 로그인 상태에서만 표시
```

### 4.7 Router 수정

```typescript
// router/index.ts에 추가

{
  path: '/notifications',
  name: 'notifications',
  component: () => import('@/views/notification/NotificationListView.vue'),
  meta: { requiresAuth: true }
}
```

### 4.8 Polling Strategy

```
폴링 조건:
├── 사용자 로그인 상태
├── 브라우저 탭이 활성화 상태 (document.visibilityState === 'visible')
└── 네트워크 연결 상태

폴링 주기:
├── 기본: 30초
├── 탭 비활성화 시: 폴링 일시 중지
└── 탭 재활성화 시: 즉시 1회 fetch 후 폴링 재개

에러 처리:
├── 연속 3회 실패 시 폴링 주기 2배로 증가 (최대 5분)
└── 성공 시 원래 주기로 복원
```

---

## 5. Testing Strategy

### 5.1 Backend Tests

#### Unit Tests
- `NotificationServiceTest`: 서비스 로직 테스트
- `NotificationEventListenerTest`: 이벤트 리스너 테스트

#### Integration Tests
- `NotificationControllerTest`: REST API 테스트 + REST Docs 생성
- `NotificationRepositoryTest`: Repository 쿼리 테스트

### 5.2 Frontend Tests

- TypeScript 타입 체크: `npm run type-check`
- 빌드 검증: `npm run build`

---

## 6. REST Docs

### 문서화 필요 엔드포인트
- GET /api/notifications
- GET /api/notifications/unread
- GET /api/notifications/count
- PATCH /api/notifications/{id}/read
- PATCH /api/notifications/read-all
- DELETE /api/notifications/{id}
- DELETE /api/notifications/read

### index.adoc 업데이트
```
== Notification API
include::{snippets}/notification-controller-test/get-notifications/auto-section.adoc[]
...
```

---

## 7. Implementation Checklist

### Phase 1: Backend Foundation
- [x] Flyway 마이그레이션 스크립트 작성
- [x] Entity, Enum, Repository 구현
- [x] DTO 구현
- [x] NotificationService 구현
- [x] NotificationController 구현
- [x] Unit/Integration 테스트 작성

### Phase 2: Event System
- [x] 도메인 이벤트 클래스 정의
- [x] NotificationEventListener 구현
- [x] AsyncConfig에 notificationExecutor 추가
- [x] FriendService에 이벤트 발행 추가
- [x] ScheduleService에 이벤트 발행 추가
- [x] NotificationCleanupScheduler 구현

### Phase 3: Frontend Implementation
- [x] TypeScript 타입 추가
- [x] notification API 클라이언트 구현
- [x] Pinia notification store 구현
- [x] NotificationBell 컴포넌트 구현
- [x] NotificationDropdown 컴포넌트 구현
- [x] NotificationListView 페이지 구현
- [x] AppHeader에 NotificationBell 통합
- [x] Router 설정 추가

### Phase 4: Polish & Documentation
- [x] REST Docs 테스트 작성
- [x] index.adoc 업데이트
- [x] 다크모드 스타일 검증
- [x] 모바일 반응형 검증
- [x] 에러 처리 및 빈 상태 UI 완성

---

## 8. API Response Examples

### GET /api/notifications/unread
```json
[
  {
    "id": "01HXYZ123456789ABCDEFGH",
    "type": "FRIEND_REQUEST_RECEIVED",
    "title": "홍길동님이 친구 요청을 보냈습니다",
    "content": null,
    "referenceType": "FRIEND_REQUEST",
    "referenceId": "123",
    "actorId": 42,
    "actorName": "홍길동",
    "actorHasProfilePhoto": true,
    "actorProfilePhotoVersion": 3,
    "isRead": false,
    "createdAt": "2024-01-15T10:30:00"
  }
]
```

### GET /api/notifications/count
```json
{
  "unreadCount": 5,
  "totalCount": 47
}
```

### PATCH /api/notifications/read-all
```json
{
  "count": 5
}
```

---

## 9. Notes & Considerations

### Performance
- 폴링 주기 30초로 서버 부하 최소화
- 미읽음 알림 최대 50개로 제한
- 30일 지난 알림 자동 삭제

### Security
- 본인 알림만 조회/수정/삭제 가능 (memberId 검증)
- @Login 어노테이션으로 인증 필수

### UX
- 알림 클릭 시 해당 컨텍스트로 자연스럽게 이동
- 99+ 표시로 과도한 숫자 방지
- 빈 상태 UI 제공

### Extensibility
- NotificationType enum 확장으로 새 알림 유형 추가 용이
- SSE 업그레이드 시 폴링 로직만 교체하면 됨
- 푸시 알림 추가 시 별도 서비스로 확장 가능

---

## 10. Dependencies

### Backend
- 기존 의존성으로 충분 (추가 라이브러리 불필요)

### Frontend
- 기존 의존성으로 충분 (추가 라이브러리 불필요)
