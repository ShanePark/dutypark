# Dutypark Refactoring Analysis

> Generated: 2026-01-16

---

## 1. Backend (Kotlin) Issues

### HIGH Priority

#### 1.1 Inconsistent Error Handling (116 occurrences)

**Problem:** Mixed usage of:
- `.orElseThrow()` (no message) - 116 instances
- `.orElseThrow { exception }` (with message)

**Files:**
- `SchedulePermissionService.kt` (lines 31, 36)
- `FriendService.kt` (12+ instances)
- `ScheduleService.kt` (8+ instances)
- `AttachmentService.kt` (lines 98, 116 - inconsistent within same file)
- `MemberService.kt` (10+ instances)

**Impact:** Generic `NoSuchElementException` without context makes debugging difficult.

**Recommendation:** Create utility extension and standardize exception types:
```kotlin
fun <T> Optional<T>.orThrow(errorMessage: String): T =
    orElseThrow { IllegalArgumentException(errorMessage) }
```

---

#### 1.2 In-Memory Filtering Performance Issue

**File:** `src/main/kotlin/com/tistory/shanepark/dutypark/member/service/FriendService.kt`

**Lines:** 235-244

**Problem:** `searchPossibleFriends()` loads ALL friends and pending requests into memory, then filters:
```kotlin
val friends = findAllFriends(login).map { it.id }  // Loads ALL friends
val pendingRequestsFrom = getPendingRequestsFrom(member).map { it.toMember.id }  // Loads ALL pending
val excludeIds = friends + pendingRequestsFrom + member.id
```

**Recommendation:** Replace with repository query using JPA subqueries for pagination efficiency.

---

### MEDIUM Priority

#### 1.3 Large Service Classes

| Service | Lines | Status | Recommendation |
|---------|-------|--------|----------------|
| `AttachmentService.kt` | 454 | ⚠️ LARGEST | Extract `AttachmentSessionService`, `AttachmentFileService` |
| `FriendService.kt` | 345 | MEDIUM | Extract `FriendRequestService` |
| `TodoService.kt` | 313 | ACCEPTABLE | Current structure is reasonable |

---

#### ~~1.4 N+1 Query Pattern~~ (RESOLVED)

**Status:** ✅ RESOLVED - Queries are properly optimized with `JOIN FETCH` and `@EntityGraph`:
- `ScheduleRepository.kt`: Uses `JOIN FETCH` for member, tags, and tag.member
- `FriendRelationRepository.kt`: Uses `@EntityGraph` for friend and friend.team

---

#### 1.5 Missing EntityGraph on FriendRelation Lookup

**File:** `FriendRelationRepository.kt` (line 13)

**Problem:** `findByMemberAndFriend()` lacks `@EntityGraph`, may cause lazy loading issues.

**Recommendation:** Add `@EntityGraph(attributePaths = ["friend", "friend.team"])`.

---

#### 1.6 Repeated Member Lookups

**File:** `FriendService.kt` (line 247)

**Problem:** `loginMemberToMember()` called 12+ times in same service, each querying DB.

**Recommendation:** Cache result or pass as parameter.

---

## 2. Frontend (Vue 3) Issues

### HIGH Priority

#### 2.1 Duplicate Local Interfaces (5 files)

**Problem:** Multiple components define local `Schedule`, `Duty`, `Todo` interfaces instead of using `@/types`.

| File | Local Interfaces | Should Use |
|------|------------------|------------|
| `DayDetailModal.vue` (lines 29-56) | Schedule, DutyType | `@/types` |
| `ScheduleViewModal.vue` (lines 19-50) | Schedule, DutyType | `@/types` |
| `TodoDetailModal.vue` (lines 27-36) | Todo | `@/types` |
| `TodoOverviewModal.vue` (lines 24-43) | Todo, attachment | `@/types` |

**Recommendation:** Remove local definitions and import from `@/types/index.ts`.

---

#### 2.2 Large Components Needing Extraction

| Component | Lines | Severity | Recommendation |
|-----------|-------|----------|----------------|
| `DutyView.vue` | 2,168 | **CRITICAL** | Extract: DutyCalendar, DutyToolbar, TodoSection, DDaySection |
| `DayDetailModal.vue` | 993 | LARGE | Split read-only view from create/edit form |
| `TodoDetailModal.vue` | 529 | ACCEPTABLE | Within reasonable bounds |

---

#### 2.3 Type Inconsistencies in Attachment Types

**File:** `src/types/index.ts`

**Problem:** Confusing naming across attachment types:
- `Attachment` (lines 71-75): Minimal properties
- `AttachmentDto` (lines 80-92): Full backend DTO
- `NormalizedAttachment` (lines 106-120): UI representation

**Recommendation:** Rename for clarity:
```typescript
export interface ScheduleAttachmentSummary { ... }  // Simple reference
export interface AttachmentDto { ... }              // Backend DTO
export interface NormalizedAttachment { ... }       // UI-ready
```

---

### MEDIUM Priority

#### 2.4 Hardcoded Pagination Values (6 occurrences)

**Problem:** `size: 10` or `size: 20` scattered across API files.

| File | Line | Value |
|------|------|-------|
| `src/api/schedule.ts` | 115 | `size: 10` |
| `src/api/admin.ts` | 32, 50 | `size: 10` |
| `src/api/team.ts` | 147 | `size: 10` |
| `src/api/member.ts` | 110 | `size: 10` |
| `src/api/notification.ts` | 8 | `size: 20` |

**Recommendation:** Create `src/config/pagination.ts`:
```typescript
export const PAGINATION_DEFAULTS = {
  SEARCH_SIZE: 10,
  NOTIFICATIONS_SIZE: 20,
  ADMIN_PAGE_SIZE: 10,
}
```

---

#### 2.5 Scattered localStorage Usage

**Status:** Partially centralized via Pinia stores, but still scattered in `DutyView.vue`.

**Centralized (Good):**
- `auth.ts` store: User data, impersonation
- `theme.ts` store: Theme preference

**Scattered (Needs Refactoring):**
- `DutyView.vue`: Todo filter settings, D-Day selection, session highlighting

**Recommendation:** Create `src/composables/useLocalStorage.ts` for unified storage access.

---

#### 2.6 Inconsistent API Client Export Patterns

**Problem:** Three different export patterns in use:

| Pattern | Files | Example |
|---------|-------|---------|
| Named export only | schedule, notification, auth, todo, duty, etc. | `export const scheduleApi = { ... }` |
| Named + default export | admin, team | `export const adminApi = { ... }; export default adminApi` |
| Multiple named + default | member | Multiple exports + default object |

**Recommendation:** Standardize to named exports only.

---

## 3. Dependencies & Configuration Issues

### HIGH Priority

#### 3.1 Spring AI Milestone Version

**File:** `build.gradle.kts` (line 27)

**Problem:** Using `springAiVersion = "2.0.0-M1"` (pre-release milestone)

**Risk:** Milestone versions may have breaking changes and are not production-ready.

**Recommendation:** Upgrade to stable `1.x` release or wait for `2.0.0` GA.

---

#### 3.2 AI Model Configuration Mismatch

**File:** `src/main/resources/application.yml` (line 29)

**Problem:** Documentation (CLAUDE.md) states "Gemini 2.0 Flash Lite" but code uses `gemma-3-27b-it`.

**Recommendation:** Update documentation or configuration to be consistent.

---

### MEDIUM Priority

#### 3.3 Misleading OpenAI Namespace for Gemini

**File:** `src/main/resources/application.yml` (lines 23-31)

**Problem:**
```yaml
spring:
  ai:
    openai:                          # Misleading namespace name
      api-key: "${GEMINI_API_KEY:EMPTY}"
      chat:
        base-url: "https://generativelanguage.googleapis.com/v1beta/openai/"
```

**Impact:** Confusing configuration; uses OpenAI-compatible protocol for Gemini.

**Recommendation:** Add clarifying comments explaining the OpenAI-compatible endpoint pattern.

---

#### ~~3.4 macOS-Specific Netty Dependency~~ (RESOLVED)

**Status:** ✅ CORRECTLY CONFIGURED

**File:** `build.gradle.kts` (line 50)

`io.netty:netty-resolver-dns-native-macos:4.1.93.Final:osx-aarch_64` is properly configured for Apple Silicon development.

---

### LOW Priority

#### 3.5 Minor Frontend Dependency Update

**File:** `frontend/package.json`

- `@types/node`: `25.0.6` → `25.0.9` available

```bash
npm update @types/node
```

---

## 4. Test Code Issues

### HIGH Priority

#### 4.1 Missing Test Coverage (2 controllers)

**Controllers without tests:**
- `DutyBatchController`
- `TeamScheduleController`

**Note:** Test coverage significantly improved - 22 of 24 controllers now have tests.

---

#### ~~4.2 Flaky Time-Dependent Tests (18 files)~~ (RESOLVED)

**Status:** ✅ RESOLVED - All test files now use fixed dates instead of `LocalDateTime.now()`.

**Fixed files:** All 18+ test files updated to use:
- Fixed date constants (`fixedDate`, `fixedDateTime`)
- Far future/past dates for time comparison tests (e.g., `2099-12-31` for "always after now")
- Current date only where the service explicitly requires it (e.g., Dashboard endpoint returns "today's" data)

**Exceptions (intentionally use current date):**
- `DashboardControllerTest.kt`: Dashboard endpoint returns data for "today" internally
- `CalendarDayServiceTest.kt`: DDayDto calculates `daysLeft` using `LocalDate.now()` internally
- `AuthServiceTest.kt`: Token validity checked against current time

---

### MEDIUM Priority

#### 4.3 Factory Method Duplication

**Problem:** `makeSchedule()` defined in 2 separate test files with different implementations:
- `ScheduleServiceIntegrationTest.kt` (line 742) - Uses `scheduleService.createSchedule()`
- `ScheduleTimeParsingQueueManagerTest.kt` (line 73) - Creates Schedule directly

**Recommendation:** Extract to shared `TestFixtures.kt`.

---

#### 4.4 Minimal Test Utilities

**Current:** `TestUtils.kt` exists but only provides `jsr310JsonMapper()` helper.

**Missing:**
- Entity factory methods (makeSchedule, makeMember, etc.)
- Fixture builders
- Test constants

**Recommendation:** Expand `TestUtils.kt` or create separate `TestFixtures.kt`:
```
src/test/kotlin/.../util/
├── TestFixtures.kt          (factory methods)
├── TestClock.kt             (fixed clock provider)
└── AssertionHelpers.kt
```

---

## 5. Recommended Refactoring Priority

### Phase 1: Immediate (Critical)
- [ ] Spring AI stable version migration
- [ ] Fix documentation/config mismatch for AI model

### Phase 2: Short-term
- [x] ~~Extract `TodoService.toTodoResponse()` helper~~ (DONE)
- [x] ~~Split `AttachmentService.finalizeSession()` into helper methods~~ (DONE)
- [x] ~~Remove duplicate file deletion logic in `AttachmentService`~~ (DONE)
- [x] ~~Resolve N+1 query patterns~~ (DONE - properly optimized)
- [ ] Consolidate frontend types in `types/index.ts`
- [ ] Remove duplicate local interfaces from modals
- [ ] Fix `FriendService.searchPossibleFriends()` performance

### Phase 3: Medium-term
- [ ] Split large components (`DutyView.vue` - 2,168 lines)
- [ ] Split `AttachmentService` into focused services
- [ ] Add missing controller tests (DutyBatchController, TeamScheduleController)
- [x] ~~Fix time-dependent tests (18 files)~~ (DONE)

### Phase 4: Long-term
- [ ] Create shared test utilities package
- [ ] Standardize error handling patterns (116 instances)
- [ ] Extract frontend constants and storage utilities
- [ ] Standardize API client export patterns

---

## Summary Table

| Area | HIGH | MEDIUM | LOW | RESOLVED |
|------|------|--------|-----|----------|
| Backend | 2 | 4 | 0 | 1 |
| Frontend | 3 | 3 | 0 | 0 |
| Config | 2 | 1 | 1 | 1 |
| Tests | 1 | 2 | 0 | 1 |
| **Total** | **8** | **10** | **1** | **3** |

---

## Completed Refactoring

### 2026-01-16
- **Time-Dependent Tests**: Fixed all 18+ test files that used `LocalDateTime.now()` or `LocalDate.now()` directly
  - Replaced with fixed date constants (`fixedDate = LocalDate.of(2025, 1, 15)`)
  - Used far future/past dates for time comparison tests
  - Documented exceptions where current date is intentionally required (Dashboard, DDayDto, token validity)

### 2026-01-15
- **TodoService**: Extracted `toResponse()` helper method, eliminating 52 lines of duplication
- **AttachmentService**:
  - Extracted `moveAttachmentToFinalLocation()`, `updateAttachmentOrdering()`, `deleteTempAttachment()` helpers
  - `finalizeSession()` reduced from 125 lines to 71 lines
  - `discardSession()` now reuses `deleteAttachment()` method
- **N+1 Query Patterns**: Verified resolved - queries properly use `JOIN FETCH` and `@EntityGraph`
- **macOS Netty Dependency**: Verified correctly configured for Apple Silicon

### Previous Improvements (Test Coverage)
- REST Docs coverage improved to 22/24 controllers documented
- Unit + integration test variants added for major services (Friend, Duty, Team, Member, Schedule)
- Total service test files: 36 (excellent coverage)
