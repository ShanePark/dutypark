# Unused Code Cleanup Plan

This document tracks the cleanup of unused code identified in the Dutypark codebase.

## Cleanup Completed (2026-01-08)

### Backend (Kotlin/Spring Boot)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | FileSystemService.moveFile() | Removed | Method only used in tests |
| 2 | StoragePathResolver.resolvePermanentFilePath() | Removed | Inlined into resolveFilePath() |
| 3 | BatchParseResult workTimeTable/offTimeTable | Removed | Properties were never accessed externally |
| 4 | TeamAdminController.memberRepository | Removed | Injected but never used |
| 5 | RefreshToken.validation() | Removed | Duplicate of isValid() |
| 6 | ErrorDetectAdvisor duplicate setColor() | Removed | Same call at line 46 already exists |
| 7 | TeamNameCheckResult.INVALID | Removed | Never used |
| 8 | WorkType.WEEKEND, WorkType.FIXED | Removed | Never used (WEEKDAY is used in DutyService.kt) |
| 9 | ManagerRole.ACCOUNT_LINKED | Removed | Never used |

### Frontend (Vue 3/TypeScript)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 10 | IntroFeature.vue | Removed | Component never imported |
| 11 | useScrollAnimation.ts | Removed | Composable never imported |
| 12 | client.ts resetRefreshState() | Removed | Function never called |
| 13 | attachment.ts duplicateFileMessage() | Removed | Function never called |
| 14 | useSwal.ts toastInfo() | Removed | Function never called |
| 15 | types/index.ts LoginResponse | Removed | Interface never used |
| 16 | types/index.ts FriendRequest | Removed | Interface never used |
| 17 | types/index.ts DashboardMyInfo | Removed | Legacy interface, never used |
| 18 | types/index.ts DashboardFriendsInfo | Removed | Legacy interface, never used |

## Verification Results

All items were verified through:
1. Grep search across entire codebase
2. Import/usage analysis
3. Compilation verification (`./gradlew compileKotlin compileTestKotlin`)
4. Frontend type check (`npm run type-check`)
5. Full build (`./gradlew build`)

## Items NOT Removed (Verified as Used)

| Item | Reason |
|------|--------|
| WorkType.WEEKDAY | Used in DutyService.kt for lazy duty initialization |

---

## Commands Reference

```bash
# Backend verification
./gradlew build
./gradlew test

# Frontend verification
cd frontend && npm run type-check
cd frontend && npm run build

# Search commands
grep -rn "targetFunction" src/main/kotlin --include="*.kt"
grep -rn "targetFunction" frontend/src --include="*.ts" --include="*.vue"
```
