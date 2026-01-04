# Profile Photo Feature - Design Document

## Overview

프로필 사진 기능 추가. 기존 attachment 시스템의 `PROFILE` context 활용.

### Design Decisions

- **Single photo per member** - 1인 1사진, 새 업로드 시 기존 사진 자동 삭제
- **Thumbnail only** - 200x200px 썸네일 URL만 반환 (기존 ThumbnailService 활용)
- **Public read / Owner write** - 프로필 사진은 누구나 볼 수 있고, 본인만 수정 가능

---

## API Specification

### Profile Photo Endpoints

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| PUT | `/api/members/profile-photo` | 프로필 사진 등록/변경 | Required |
| DELETE | `/api/members/profile-photo` | 프로필 사진 삭제 | Required |

### Request/Response

**PUT /api/members/profile-photo**

Request:
```json
{
  "sessionId": "uuid-string",
  "attachmentId": "uuid-string"
}
```

Response: `200 OK`
```json
{
  "profilePhotoUrl": "/api/attachments/{id}/thumbnail"
}
```

**DELETE /api/members/profile-photo**

Response: `204 No Content`

---

## DTO Extensions

### Backend DTOs

기존 DTO에 `profilePhotoUrl: String? = null` 필드 추가:

| DTO | 용도 |
|-----|------|
| `MemberDto` | 내 정보, 멤버 조회 |
| `FriendDto` | 친구 목록, 가족 목록 |
| `TeamMemberDto` | 팀원 목록 |

> 백엔드 Dashboard DTOs는 MemberDto/FriendDto를 embed하므로 자동 적용
> 프론트엔드는 DashboardMemberDto/DashboardFriendDto가 별도 정의 → 각각 수정 필요

### Frontend Types

```typescript
// 기존 타입에 profilePhotoUrl 필드 추가
interface MemberDto { ... profilePhotoUrl: string | null }
interface FriendDto { ... profilePhotoUrl: string | null }
interface TeamMemberDto { ... profilePhotoUrl: string | null }

// Dashboard 타입도 별도 정의되어 있으므로 추가 필요
interface DashboardMemberDto { ... profilePhotoUrl: string | null }
interface DashboardFriendDto { ... profilePhotoUrl: string | null }

// 새 타입
interface UpdateProfilePhotoRequest {
  sessionId: string
  attachmentId: string
}

interface ProfilePhotoResponse {
  profilePhotoUrl: string | null
}
```

---

## Backend Implementation

### 1. AttachmentPermissionEvaluator

`PROFILE` context 권한 체크 추가:
- **Read**: 로그인 불필요 (public)
- **Write**: 본인만 가능 (`contextId == loginMember.id.toString()`)

### 2. AttachmentRepository

메서드 추가:
```kotlin
fun findFirstByContextTypeAndContextId(
    contextType: AttachmentContextType,
    contextId: String
): Attachment?
```

### 3. ProfilePhotoService (신규)

| Method | Description |
|--------|-------------|
| `getProfilePhoto(memberId)` | Attachment? 반환 |
| `getProfilePhotoUrl(memberId)` | URL string 반환 (또는 null) |
| `setProfilePhoto(loginMember, sessionId, attachmentId)` | 기존 삭제 + 새 사진 설정 |
| `deleteProfilePhoto(loginMember)` | 프로필 사진 삭제 |

> `synchronizeContextAttachments()` 활용 - orderedIds에 새 사진만 넣으면 기존 자동 삭제

### 4. Service Layer Updates

DTO 반환 시 `.copy(profilePhotoUrl = ...)` 패턴으로 URL 채움:

**MemberService:**
- `findById()`, `findAll()`, `findAllManagers()`

**FriendService:**
- `findAllFriends()`, `findAllFamilyMembers()`, `searchPossibleFriends()`

**DashboardService:**
- `my()`, `friend()`

**TeamDto.of():**
- `TeamMemberDto` 생성 시 URL 채움

### 5. MemberController

프로필 사진 엔드포인트 추가 (위 API 스펙 참조)

---

## Frontend Implementation

### 1. API Client (`api/member.ts`)

```typescript
memberApi.updateProfilePhoto(request: UpdateProfilePhotoRequest): Promise<ProfilePhotoResponse>
memberApi.deleteProfilePhoto(): Promise<void>
```

### 2. Components

**ProfileAvatar.vue** (공통)
- Props: `photoUrl`, `size` (sm/md/lg/xl)
- 사진 없으면 기본 이미지 (사람 실루엣 아이콘)

**ProfilePhotoUploader.vue** (멤버 전용)
- 기존 `FileUploader.vue` 활용 (`contextType="PROFILE"`)
- 업로드 완료 시 API 호출하여 서버에 저장

### 3. View Updates

**MemberView.vue**
- 기본 정보 섹션에 `ProfilePhotoUploader` 추가

**DashboardView.vue**
- 내 정보 헤더: User 아이콘 → `ProfileAvatar`
- 친구 카드: Home/User 아이콘 → `ProfileAvatar`

---

## Storage Structure

```
/dutypark/storage/PROFILE/{memberId}/
├── {uuid}.jpg           # Original
└── thumb-{uuid}.png     # Thumbnail (200x200)
```

---

## Implementation Checklist

### Backend

- [ ] `AttachmentRepository` - findFirst 메서드 추가
- [ ] `AttachmentPermissionEvaluator` - PROFILE 권한 체크
- [ ] `ProfilePhotoService` - 신규 서비스
- [ ] `MemberDto`, `FriendDto`, `TeamMemberDto` - profilePhotoUrl 필드
- [ ] `MemberController` - PUT/DELETE 엔드포인트
- [ ] `MemberService`, `FriendService`, `DashboardService`, `TeamDto` - URL 채우기

### Frontend

- [ ] `types/index.ts` - 타입 확장 (MemberDto, FriendDto, TeamMemberDto, DashboardMemberDto, DashboardFriendDto)
- [ ] `api/member.ts` - API 메서드
- [ ] `ProfileAvatar.vue` - 아바타 컴포넌트
- [ ] `ProfilePhotoUploader.vue` - 업로더 컴포넌트
- [ ] `MemberView.vue` - 업로더 통합
- [ ] `DashboardView.vue` - 아바타 표시

---

## Notes

1. **기존 코드 재사용**: AttachmentService, ThumbnailService, FileUploader.vue 그대로 활용
2. **DB 변경 없음**: 기존 attachment 테이블이 PROFILE context 지원
3. **캐시**: 구현 후 필요시 추가 검토
