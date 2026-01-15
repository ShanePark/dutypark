# Dutypark Refactoring Analysis

> Generated: 2026-01-15

---

## 1. Backend (Kotlin) Issues

### MEDIUM Priority

#### 1.1 Inconsistent Error Handling (19+ occurrences)

**Problem:** Mixed usage of:
- `.orElseThrow()` (no message)
- `.orElseThrow { exception }` (with message)

**Files:**
- `SchedulePermissionService.kt` (lines 31, 36)
- `FriendService.kt` (multiple lines)
- Various other services

**Recommendation:** Create utility function:
```kotlin
fun <T> Optional<T>.orThrow(errorMessage: String): T =
    orElseThrow { IllegalArgumentException(errorMessage) }
```

---

#### 1.2 N+1 Query Pattern

**File:** `src/main/kotlin/com/tistory/shanepark/dutypark/schedule/service/ScheduleService.kt`

**Lines:** 65-94

**Problem:** In `findSchedulesByYearAndMonth()`, attachments are fetched separately then grouped.

**Recommendation:** Add repository method with JOIN FETCH for eager loading.

---

#### 1.3 Large Service Classes

| Service | Lines | Recommendation |
|---------|-------|----------------|
| `AttachmentService.kt` | 465 | Split into Upload/Permission/Session services |
| `TodoService.kt` | 365 | Extract `TodoQueryService` |
| `FriendService.kt` | 345 | Consider `FriendRelationService` + `FriendRequestService` |

---

## 2. Frontend (Vue 3) Issues

### HIGH Priority

#### 2.1 Duplicate Local Interfaces

**Problem:** Multiple components define local `Schedule`, `Duty`, `Todo` interfaces instead of using `@/types`.

**Files:**
- `src/views/duty/DutyView.vue` (lines 71-100)
- `src/components/duty/DayDetailModal.vue` (lines 29-50, 52-56, 79-88)
- `src/components/duty/ScheduleViewModal.vue` (lines 19-50)
- `src/components/duty/TodoDetailModal.vue` (lines 27-36)
- `src/components/duty/TodoOverviewModal.vue` (lines 24-36)

**Recommendation:** Extend centralized types in `types/index.ts` with all necessary fields (`taggedBy`, `daysFromStart`, `totalDays`, etc.)

---

#### 2.2 Large Components Needing Extraction

| Component | Lines | Recommendation |
|-----------|-------|----------------|
| `DutyView.vue` | 2,168 | Extract: DutyCalendar, DutyToolbar, DutyStateManager composables |
| `DayDetailModal.vue` | 993 | Extract: ScheduleList, TodoSection, DutySelector sub-components |
| `TodoDetailModal.vue` | 529 | Extract: TodoForm, AttachmentSection sub-components |

---

### MEDIUM Priority

#### 2.3 Hardcoded Pagination Values

**Problem:** `size: 10` or `size: 20` scattered across API files without centralized constants.

**Files:**
- `src/api/schedule.ts` (line 115)
- `src/api/admin.ts` (lines 32, 50)
- `src/api/team.ts` (line 147)
- `src/api/member.ts` (line 110)
- `src/api/notification.ts` (line 8)

**Recommendation:** Create `src/constants/api.ts`:
```typescript
export const API_PAGINATION_DEFAULTS = {
  SEARCH_SIZE: 10,
  NOTIFICATIONS_SIZE: 20,
  ADMIN_PAGE_SIZE: 10,
}
```

---

#### 2.4 Scattered localStorage Usage

**Files with direct localStorage/sessionStorage calls:**
- `src/stores/theme.ts` (lines 10-16, 31)
- `src/views/duty/DutyView.vue`
- `src/composables/useNotificationNavigation.ts` (line 55)
- `src/components/common/PWAInstallGuide.vue`
- `src/components/common/PushPermissionGuide.vue`
- `src/views/auth/LoginView.vue`

**Recommendation:** Create `src/utils/storage.ts` utility wrapper.

---

#### 2.5 Type Inconsistencies in Attachment DTO

**File:** `src/types/index.ts`

**Problem:**
- `Attachment.originalFileName` vs `AttachmentDto.originalFilename` (casing)
- `Attachment.thumbnailAvailable` vs `AttachmentDto.hasThumbnail` (naming)

**Recommendation:** Standardize naming across interfaces.

---

#### 2.6 Inconsistent API Client Patterns

**Problem:** Mixed default export patterns.

**Files:**
- `src/api/member.ts` (lines 248-253): Exports object with multiple APIs
- `src/api/admin.ts` (line 78): `export default adminApi`
- `src/api/team.ts` (line 211): `export default teamApi`

**Recommendation:** Standardize on named exports only.

---

## 3. Dependencies & Configuration Issues

### HIGH Priority

#### 3.1 Spring AI Milestone Version

**File:** `build.gradle.kts`

**Problem:** Using `springAiVersion = "2.0.0-M1"` (pre-release)

**Risk:** Milestone versions may have breaking changes.

**Recommendation:** Upgrade to stable `2.0.0` when available or use latest `1.x` stable.

---

#### 3.2 macOS-Specific Netty Dependency

**File:** `build.gradle.kts`

**Problem:** `io.netty:netty-resolver-dns-native-macos:4.1.93.Final:osx-aarch_64`

**Risk:** Will break on Linux/Windows servers.

**Recommendation:** Remove or make conditional for dev environments only.

---

### MEDIUM Priority

#### 3.3 AI Rate Limit Configuration Mismatch

**File:** `src/main/resources/application.yml`

**Problem:**
```yaml
rate-limit:
  rpm: 30        # Requests per minute
  rpd: 14400     # Requests per day (too high)
```

**Issue:** `rpd: 14400` conflicts with Gemini's typical 1500 RPD quota.

**Recommendation:** Verify and align with actual Gemini API quota.

---

#### 3.4 OpenAI Namespace for Gemini Config

**File:** `src/main/resources/application.yml`

**Problem:**
```yaml
spring:
  ai:
    openai:                          # Using "openai" namespace
      api-key: "${GEMINI_API_KEY:EMPTY}"  # But pointing to Gemini
```

**Recommendation:** Add clarifying comments or restructure if Spring AI supports direct Gemini config.

---

### LOW Priority

#### 3.5 Minor Frontend Dependency Update

**File:** `frontend/package.json`

- `@types/node`: `25.0.6` → `25.0.8` available

```bash
npm update @types/node
```

---

## 4. Test Code Issues

### HIGH Priority

#### 4.1 Missing Test Coverage (16 services/controllers)

**Controllers without tests:**
- `OAuthController`
- `AdminController`
- `CommonController`
- `RefreshTokenController`
- `TeamAdminController`
- `TeamManageController`
- `TeamManageDutyTypeController`
- `PolicyController`

**Services without tests:**
- `KakaoLoginService`
- `AuthService`
- `DashboardService`
- `DDayService`
- `ConsentService`
- `CookieService`
- `WebPushService`
- `SchedulePermissionService`
- `PolicyService`

---

#### 4.2 REST Docs Coverage Gap

**Current:** ~56% (14/25 controllers documented)

**Missing REST Docs:**
- All 8 controllers listed above
- Incomplete docs for: `ScheduleController`, `DashboardController`, `TodoController`

---

### MEDIUM Priority

#### 4.3 Factory Method Duplication

**Problem:** `makeSchedule()` defined in 3 separate test files:
- `ScheduleSearchServiceDBImplTest.kt`
- `ScheduleServiceTest.kt`
- `ScheduleTimeParsingQueueManagerTest.kt`

**Recommendation:** Extract to shared `TestFixtures.kt`

---

#### 4.4 Flaky Time-Dependent Tests

**Problem:** 12 files use `LocalDateTime.now()` directly

**Files:**
- `ScheduleTimeParsingQueueManagerTest.kt`
- `TeamScheduleServiceTest.kt`
- `BaseTimeEntityTest.kt`
- `RefreshTokenTest.kt`
- `TodoEntityTest.kt`
- `AttachmentControllerTest.kt`
- `AttachmentControllerEdgeCaseTest.kt`
- `ScheduleControllerTest.kt`
- `DashboardControllerTest.kt`

**Recommendation:** Use fixed `Clock` instance (good pattern exists in `AttachmentServiceTest.kt`)

---

### LOW Priority

#### 4.5 Missing Shared Test Utilities

**Recommendation:** Create test utilities package:
```
src/test/kotlin/.../util/
├── TestFixtures.kt          (factory methods)
├── TestClock.kt             (fixed clock provider)
├── FakeRepositories.kt      (all Fake* classes)
├── RestDocumentationHelper.kt
└── AssertionHelpers.kt
```

---

## 5. Recommended Refactoring Priority

### Phase 1: Immediate (Critical)
- [ ] Spring AI stable version migration
- [ ] Remove macOS-specific Netty dependency

### Phase 2: Short-term (1-2 weeks)
- [x] ~~Extract `TodoService.toTodoResponse()` helper~~ (DONE)
- [x] ~~Split `AttachmentService.finalizeSession()` into helper methods~~ (DONE)
- [x] ~~Remove duplicate file deletion logic in `AttachmentService`~~ (DONE)
- [ ] Consolidate frontend types in `types/index.ts`
- [ ] Fix AI rate limit configuration

### Phase 3: Medium-term
- [ ] Split large components (`DutyView.vue`, `DayDetailModal.vue`)
- [ ] Split `AttachmentService` into focused services
- [ ] Add missing REST Docs tests

### Phase 4: Long-term
- [ ] Create shared test utilities package
- [ ] Standardize error handling patterns
- [ ] Extract frontend constants and utilities

---

## Summary Table

| Area | HIGH | MEDIUM | LOW |
|------|------|--------|-----|
| Backend | 0 | 3 | 1 |
| Frontend | 2 | 4 | 2 |
| Config | 2 | 2 | 1 |
| Tests | 2 | 2 | 1 |
| **Total** | **6** | **11** | **5** |

---

## Completed Refactoring (2026-01-15)

- **TodoService**: Extracted `toResponse()` helper method, eliminating 52 lines of duplication
- **AttachmentService**:
  - Extracted `moveAttachmentToFinalLocation()`, `updateAttachmentOrdering()`, `deleteTempAttachment()` helpers
  - `finalizeSession()` reduced from 125 lines to 71 lines
  - `discardSession()` now reuses `deleteAttachment()` method
