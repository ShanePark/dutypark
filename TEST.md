# Test Analysis Report

This document analyzes all test files in the Dutypark project to identify integration tests that could be converted to unit tests for faster build times.

## Executive Summary

| Metric | Count |
|--------|-------|
| **Total Test Files** | 90+ |
| **Already Unit Tests** | ~55 → **~66** |
| **Integration Tests (Keep)** | ~25 → **~30** (분리된 Integration 테스트 포함) |
| **Conversion Candidates** | ~~15~~ → **1** (BaseTimeEntityTest만 남음) |
| **Estimated Time Savings** | 30-40% reduction in test execution time |

### Progress Summary (2025-01-16)
- ✅ Phase 1: 5/5 완료
- 🔄 Phase 2: 3/4 완료 (BaseTimeEntityTest 미변환)
- ✅ Phase 3: 3/3 완료

---

## Package-by-Package Analysis

### 1. Attachment Package (17 tests)

| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| AttachmentValidationServiceTest | Unit | Keep | - |
| ImageThumbnailGeneratorTest | Unit | Keep | - |
| CreateSessionResponseTest | Unit | Keep | - |
| AttachmentDtoTest | Unit | Keep | - |
| AttachmentUploadSessionServiceTest | Unit | Keep | - |
| AttachmentPermissionEvaluatorTest | Unit | Keep | - |
| FileSystemServiceTest | Unit | Keep | - |
| StoragePathResolverTest | Unit | Keep | - |
| AttachmentServiceTest | Unit | Keep | - |
| AttachmentCleanupIntegrationTest | Integration | Keep | - |
| AttachmentSessionControllerTest | Integration (REST Docs) | Keep | - |
| AttachmentControllerTest | Integration (REST Docs) | Keep | - |
| AttachmentRepositoryTest | Integration (@DataJpaTest) | Keep | - |
| AttachmentUploadSessionRepositoryTest | Integration (@DataJpaTest) | Keep | - |
| AttachmentRepositoryNPlusOneTest | Integration | Keep | - |
| ThumbnailServiceTest | Mixed | **Refactor** | Low |
| AttachmentControllerEdgeCaseTest | Integration (REST Docs) | Keep | - |

**Notes:**
- Well-structured package with 9 unit tests already
- ThumbnailServiceTest has one integration test method that should be extracted to a separate file

---

### 2. Schedule Package (12 tests)

| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| ScheduleSaveDtoTest | Unit | Keep | - |
| ScheduleDtoTest | Unit | Keep | - |
| ScheduleTimeParsingWorkerTest | Unit | Keep | - |
| ScheduleTimeParsingPreFilterTest | Unit | Keep | - |
| ScheduleTimeParsingQueueManagerTest | Unit | Keep | - |
| SchedulePermissionServiceTest | Unit | Keep | - |
| ScheduleTimeParsingTaskTest | Unit | Keep | - |
| ScheduleSearchServiceDBImplTest | Integration | Keep | - |
| ScheduleAttachmentDeletionIntegrationTest | Integration | Keep | - |
| ScheduleControllerTest | Integration (REST Docs) | Keep | - |
| ScheduleTimeParsingServiceTest | Integration (Disabled) | Skip | - |
| ~~**ScheduleServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| ScheduleServiceIntegrationTest | Integration | Keep | - |

**~~Priority Conversion: ScheduleServiceTest.kt~~** ✅ CONVERTED
- ScheduleServiceTest.kt → 유닛 테스트로 변환 완료
- ScheduleServiceIntegrationTest.kt → 복잡한 Integration 테스트 분리

---

### 3. Member Package (12 tests)

| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| FriendServiceUnitTest | Unit | Keep | - |
| DDayControllerTest | Integration (REST Docs) | Keep | - |
| FriendControllerTest | Integration (REST Docs) | Keep | - |
| RefreshTokenControllerTest | Integration (REST Docs) | Keep | - |
| MemberControllerTest | Integration (REST Docs) | Keep | - |
| ProfilePhotoServiceTest | Integration | Keep (File I/O) | - |
| ~~**RefreshTokenServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| ~~**CalendarDayServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| ~~**ConsentServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| ~~**DDayServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| ~~**FriendServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| FriendServiceIntegrationTest | Integration | Keep | - |
| ~~**MemberServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| MemberServiceIntegrationTest | Integration | Keep | - |

**~~Priority Conversions:~~** ✅ ALL CONVERTED
1. ~~**RefreshTokenServiceTest**~~ - 유닛 테스트로 변환 완료
2. ~~**CalendarDayServiceTest**~~ - 유닛 테스트로 변환 완료
3. ~~**ConsentServiceTest**~~ - 유닛 테스트로 변환 완료
4. ~~**DDayServiceTest**~~ - 유닛 테스트로 변환 완료
5. ~~**FriendServiceTest**~~ - FriendServiceIntegrationTest로 이름 변경 (FriendServiceUnitTest 이미 존재)
6. ~~**MemberServiceTest**~~ - 유닛 테스트로 변환 + MemberServiceIntegrationTest 분리

---

### 4. Security Package (10 tests)

| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| AdminAuthFilterTest | Unit | Keep | - |
| UserAgentInfoTest | Unit | Keep | - |
| RefreshTokenTest | Unit | Keep | - |
| KakaoLoginServiceTest | Unit | Keep | - |
| AuthServiceTest | Unit | Keep | - |
| CookieServiceTest | Unit | Keep | - |
| AuthControllerRateLimitTest | Integration | Keep | - |
| AuthControllerTest | Integration | Keep | - |
| OAuthControllerTest | Integration | Keep | - |
| ~~**LoginAttemptServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |

**Notes:**
- 60% already unit tests with proper mocking
- Controller tests must remain integration for security validation
- ~~Only LoginAttemptServiceTest is a conversion candidate~~ ✅ 변환 완료

---

### 5. Team Package (8 tests)

| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| TeamScheduleServiceTest | Unit | Keep | - |
| TeamServiceTest | Unit | Keep | - |
| TeamDtoTest | Unit | Keep | - |
| TeamServiceIntegrationTest | Integration | Keep (Cascade tests) | - |
| TeamControllerTest | Integration (REST Docs) | Keep | - |
| TeamAdminControllerTest | Integration | Keep (Security) | - |
| TeamManageControllerTest | Integration (REST Docs) | Keep | - |
| TeamManageDutyTypeControllerTest | Integration (REST Docs) | Keep | - |

**Notes:**
- Well-balanced test suite - no conversions needed
- Integration tests have legitimate database/security dependencies

---

### 6. Duty Package (6 test files, 131 tests)

| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| DutyBatchSungsimServiceTest | Unit | Keep | - |
| SungsimCakeParserTest202501 | Unit | Keep | - |
| SungsimCakeParserTest202502 | Unit | Keep | - |
| DutyControllerTest | Integration (REST Docs) | Keep | - |
| ~~**DutyTypeServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| DutyTypeServiceIntegrationTest | Integration | Keep | - |
| ~~**DutyServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |
| DutyServiceIntegrationTest | Integration | Keep | - |

**~~Priority Conversions:~~** ✅ ALL CONVERTED

**~~DutyTypeServiceTest~~** ✅ CONVERTED
- DutyTypeServiceTest.kt → 유닛 테스트로 변환 완료
- DutyTypeServiceIntegrationTest.kt → Cascade delete 등 JPA 의존 테스트 분리

**~~DutyServiceTest~~** ✅ CONVERTED
- DutyServiceTest.kt → 유닛 테스트로 변환 완료
- DutyServiceIntegrationTest.kt → Visibility/permission 등 복잡한 테스트 분리

---

### 7. Other Packages

#### Todo Package (4 tests)
| File | Current Type | Recommendation |
|------|--------------|----------------|
| TodoEntityTest | Unit | Keep |
| TodoServiceTest | Unit | Keep |
| TodoRepositoryTest | Integration (@DataJpaTest) | Keep |
| TodoControllerTest | Integration (REST Docs) | Keep |

#### Common Package
| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| EntityBaseTest | Unit | Keep | - |
| SlackNotifierTest | Unit | Keep | - |
| CommonControllerTest | Integration | Keep | - |
| **BaseTimeEntityTest** | Integration | **CONVERT** | **Low** |
| **WebhookTest** | Integration (Disabled) | **CONVERT/Remove** | **Low** |

#### Holiday Package (3 tests)
| File | Current Type | Recommendation |
|------|--------------|----------------|
| HolidayServiceTest | Unit | Keep |
| HolidayAPIDataGoKrTest | Unit | Keep |
| HolidayControllerTest | Integration (REST Docs) | Keep |

#### Dashboard Package (2 tests)
| File | Current Type | Recommendation |
|------|--------------|----------------|
| DashboardServiceTest | Unit | Keep |
| DashboardControllerTest | Integration | Keep |

#### Notification Package (4 tests)
| File | Current Type | Recommendation |
|------|--------------|----------------|
| NotificationServiceTest | Unit | Keep |
| NotificationEventListenerTest | Unit | Keep |
| NotificationTypeTest | Unit | Keep |
| NotificationControllerTest | Integration | Keep |

#### Policy Package (2 tests)
| File | Current Type | Recommendation | Complexity |
|------|--------------|----------------|------------|
| PolicyControllerTest | Integration | Keep | - |
| ~~**PolicyServiceTest**~~ | ~~Integration~~ | ~~**CONVERT**~~ | ✅ **DONE** |

#### Push Package (3 tests)
| File | Current Type | Recommendation |
|------|--------------|----------------|
| WebPushServiceTest | Unit | Keep |
| WebPushConfigTest | Unit | Keep |
| PushControllerTest | Integration | Keep |

#### Admin Package (1 test)
| File | Current Type | Recommendation |
|------|--------------|----------------|
| AdminControllerTest | Integration | Keep |

---

## Conversion Priority Matrix

### High Priority (High Impact, Low-Medium Complexity) ✅ COMPLETE

| Test File | Tests | Complexity | Est. Time | Impact | Status |
|-----------|-------|------------|-----------|--------|--------|
| ~~ScheduleServiceTest~~ | 35 | High | 4-6 hrs | Very High | ✅ |
| ~~FriendServiceTest~~ | 22 | Medium | 3-4 hrs | High | ✅ |
| ~~MemberServiceTest~~ | 13 | Medium-High | 3-4 hrs | High | ✅ |

### Medium Priority (Medium Impact, Low Complexity) ✅ COMPLETE

| Test File | Tests | Complexity | Est. Time | Impact | Status |
|-----------|-------|------------|-----------|--------|--------|
| ~~DutyServiceTest~~ | 7-10 | Medium | 2-3 hrs | Medium | ✅ |
| ~~DutyTypeServiceTest~~ | 5 | Low | 1-2 hrs | Medium | ✅ |
| ~~DDayServiceTest~~ | 10 | Low | 1-2 hrs | Medium | ✅ |
| ~~CalendarDayServiceTest~~ | 10 | Low | 1-2 hrs | Medium | ✅ |

### Low Priority (Quick Wins) 🔄 MOSTLY COMPLETE

| Test File | Tests | Complexity | Est. Time | Impact | Status |
|-----------|-------|------------|-----------|--------|--------|
| ~~RefreshTokenServiceTest~~ | 5 | Low | 1 hr | Low | ✅ |
| ~~ConsentServiceTest~~ | 1 | Low | 30 min | Low | ✅ |
| ~~LoginAttemptServiceTest~~ | ~5 | Low | 1 hr | Low | ✅ |
| ~~PolicyServiceTest~~ | ~3 | Low | 1 hr | Low | ✅ |
| BaseTimeEntityTest | ~3 | Low | 1 hr | Low | ⏳ |

---

## Recommended Conversion Order

### Phase 1: Quick Wins (Est. 4-5 hours) ✅ COMPLETE
- [x] 1. ConsentServiceTest
- [x] 2. RefreshTokenServiceTest
- [x] 3. LoginAttemptServiceTest
- [x] 4. PolicyServiceTest
- [x] 5. DutyTypeServiceTest (5 tests) → DutyTypeServiceIntegrationTest 분리

### Phase 2: Medium Effort (Est. 6-8 hours) 🔄 IN PROGRESS
- [x] 6. CalendarDayServiceTest
- [x] 7. DDayServiceTest
- [x] 8. DutyServiceTest (partial) → DutyServiceIntegrationTest 분리
- [ ] 9. BaseTimeEntityTest

### Phase 3: High Effort (Est. 10-14 hours) ✅ COMPLETE
- [x] 10. FriendServiceTest → FriendServiceIntegrationTest로 이름 변경 (복잡한 DB 로직 유지)
- [x] 11. MemberServiceTest → MemberServiceIntegrationTest 분리
- [x] 12. ScheduleServiceTest (partial) → ScheduleServiceIntegrationTest 분리

---

## Tests That Must Remain Integration

The following categories should NOT be converted:

### 1. REST Docs Tests
All tests extending `RestDocsTest` must remain integration tests:
- REST Docs framework requires full Spring context
- Endpoint contract documentation depends on real HTTP
- Per CLAUDE.md guidelines

### 2. Repository Tests (@DataJpaTest)
- Query logic verification requires actual database
- JPA cascade behavior testing
- N+1 query detection

### 3. Security-Critical Tests
- OAuth flow tests
- Rate limiting tests
- Authentication/authorization tests

### 4. File System Tests
- Attachment cleanup tests
- Profile photo tests
- Tests involving actual file I/O

### 5. Cascade Delete Tests
- Tests verifying JPA cascade behavior
- Multi-entity relationship tests

---

## Unit Test Patterns to Follow

### Good Example: TodoServiceTest
```kotlin
@ExtendWith(MockitoExtension::class)
class TodoServiceTest {
    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var todoRepository: TodoRepository

    @InjectMocks
    private lateinit var todoService: TodoService

    @Test
    fun `test business logic`() {
        // Given
        whenever(todoRepository.findById(any())).thenReturn(Optional.of(mockTodo))

        // When
        val result = todoService.getTodo(1L)

        // Then
        assertThat(result).isNotNull()
        verify(todoRepository).findById(1L)
    }
}
```

### Good Example: FriendServiceUnitTest
```kotlin
@ExtendWith(MockitoExtension::class)
class FriendServiceUnitTest {
    @Mock
    private lateinit var friendRepository: FriendRelationRepository

    // Uses full mocking with @Mock annotations
    // Tests only business logic without Spring context
}
```

---

## Expected Outcomes

After completing all conversions:

| Metric | Before | Current (Jan 2025) | Target |
|--------|--------|-------------------|--------|
| Build Time | ~2+ min | TBD | ~1.2-1.5 min |
| Integration Tests | ~35 | ~30 (분리 포함) | ~20 |
| Unit Tests | ~55 | ~66 | ~70 |
| Test Reliability | Good | Better | Better |
| CI/CD Speed | Slow | Improved | 30-40% faster |

**Note:** BaseTimeEntityTest 1건만 남음. 변환하거나 JPA 의존으로 유지 결정 필요.

---

## Notes

1. **Never convert REST Docs tests** - They require full Spring context for documentation generation
2. **Repository tests should stay integration** - Query verification needs actual database
3. **Use FakeRepository pattern** when mocking is complex (see AttachmentServiceTest)
4. **Follow TDD cadence** - Convert one test at a time, verify passes, then proceed
5. **Maintain test coverage** - Conversion should not reduce test quality
