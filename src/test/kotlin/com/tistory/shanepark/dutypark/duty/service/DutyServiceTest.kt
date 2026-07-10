package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.inOrder
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.time.YearMonth
import java.util.*

@ExtendWith(MockitoExtension::class)
internal class DutyServiceTest {

    private lateinit var dutyService: DutyService

    @Mock
    lateinit var dutyRepository: DutyRepository

    @Mock
    lateinit var dutyTypeRepository: DutyTypeRepository

    @Mock
    lateinit var memberRepository: MemberRepository

    @Mock
    lateinit var friendService: FriendService

    @Mock
    lateinit var memberService: MemberService

    @Mock
    lateinit var dutyResolver: DutyResolver

    @BeforeEach
    fun setUp() {
        dutyService = DutyService(
            dutyRepository = dutyRepository,
            dutyTypeRepository = dutyTypeRepository,
            memberRepository = memberRepository,
            friendService = friendService,
            memberService = memberService,
            dutyResolver = dutyResolver,
        )
    }

    private fun createMember(id: Long, name: String = "test"): Member {
        return Member(name = name).also {
            ReflectionTestUtils.setField(it, "id", id)
        }
    }

    private fun createTeam(id: Long, name: String = "team"): Team {
        return Team(name).also {
            ReflectionTestUtils.setField(it, "id", id)
        }
    }

    private fun createDutyType(id: Long, name: String, team: Team): DutyType {
        return DutyType(name = name, position = 0, team = team, color = "#ffb3ba").also {
            ReflectionTestUtils.setField(it, "id", id)
        }
    }

    @Test
    @DisplayName("create new duty")
    fun create() {
        // Given
        val memberId = 1L
        val dutyTypeId = 10L
        val member = createMember(memberId)
        val team = createTeam(1L)
        member.team = team
        val dutyType = createDutyType(dutyTypeId, "오전", team)

        val dto = DutyUpdateDto(
            year = 2022,
            month = 10,
            day = 10,
            dutyTypeId = dutyTypeId,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(dutyTypeId)).thenReturn(Optional.of(dutyType))
        whenever(dutyRepository.findByMemberAndDutyDate(member, LocalDate.of(2022, 10, 10)))
            .thenReturn(null)
        whenever(dutyRepository.save(any<Duty>())).thenAnswer { it.arguments[0] }

        // When
        dutyService.update(dto)

        // Then
        verify(memberRepository).findMemberWithTeamForUpdate(memberId)
        verify(dutyTypeRepository).findById(dutyTypeId)
        verify(dutyRepository).save(any<Duty>())
        inOrder(memberRepository, dutyRepository) {
            verify(memberRepository).findMemberWithTeamForUpdate(memberId)
            verify(dutyRepository).findByMemberAndDutyDate(member, LocalDate.of(2022, 10, 10))
        }
    }

    @Test
    @DisplayName("change original duty to new duty")
    fun update() {
        // Given
        val memberId = 1L
        val oldDutyTypeId = 10L
        val newDutyTypeId = 11L
        val member = createMember(memberId)
        val team = createTeam(1L)
        member.team = team
        val oldDutyType = createDutyType(oldDutyTypeId, "오전", team)
        val newDutyType = createDutyType(newDutyTypeId, "오후", team)
        val existingDuty = Duty(
            dutyDate = LocalDate.of(2022, 10, 10),
            dutyType = oldDutyType,
            member = member
        )

        val dto = DutyUpdateDto(
            year = 2022,
            month = 10,
            day = 10,
            dutyTypeId = newDutyTypeId,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(newDutyTypeId)).thenReturn(Optional.of(newDutyType))
        whenever(dutyRepository.findByMemberAndDutyDate(member, LocalDate.of(2022, 10, 10)))
            .thenReturn(existingDuty)

        // When
        dutyService.update(dto)

        // Then
        assertThat(existingDuty.dutyType).isEqualTo(newDutyType)
        verify(dutyRepository, never()).save(any<Duty>())
    }

    @Test
    @DisplayName("delete original duty")
    fun delete() {
        // Given
        val memberId = 1L
        val dutyTypeId = 10L
        val member = createMember(memberId)
        val team = createTeam(1L)
        member.team = team
        val dutyType = createDutyType(dutyTypeId, "오전", team)
        val existingDuty = Duty(
            dutyDate = LocalDate.of(2022, 10, 10),
            dutyType = dutyType,
            member = member
        )

        val dto = DutyUpdateDto(
            year = 2022,
            month = 10,
            day = 10,
            dutyTypeId = null,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyRepository.findByMemberAndDutyDate(member, LocalDate.of(2022, 10, 10)))
            .thenReturn(existingDuty)

        // When
        dutyService.update(dto)

        // Then
        assertThat(existingDuty.dutyType).isNull()
    }

    @Test
    @DisplayName("wrong member Id")
    fun wrongMemberId() {
        // Given
        val invalidMemberId = -1L
        val dto = DutyUpdateDto(
            year = 2022,
            month = 10,
            day = 10,
            dutyTypeId = null,
            memberId = invalidMemberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(invalidMemberId)).thenReturn(Optional.empty())

        // When & Then
        assertThrows<NoSuchElementException> {
            dutyService.update(dto)
        }
    }

    @Test
    @DisplayName("wrong duty Type Id")
    fun wrongDutyTypeId() {
        // Given
        val memberId = 1L
        val invalidDutyTypeId = -1L
        val member = createMember(memberId)

        val dto = DutyUpdateDto(
            year = 2022,
            month = 10,
            day = 10,
            dutyTypeId = invalidDutyTypeId,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(invalidDutyTypeId)).thenReturn(Optional.empty())

        // When & Then
        assertThrows<NoSuchElementException> {
            dutyService.update(dto)
        }
    }

    @Test
    fun `duty update rejects a duty type owned by another team`() {
        val member = createMember(1L).apply { team = createTeam(1L) }
        val otherType = createDutyType(10L, "외부근무", createTeam(2L))
        val dto = DutyUpdateDto(2026, 7, 10, otherType.id, member.id!!)
        whenever(memberRepository.findMemberWithTeamForUpdate(member.id!!)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(otherType.id!!)).thenReturn(Optional.of(otherType))

        val exception = assertThrows<IllegalArgumentException> { dutyService.update(dto) }

        assertThat(exception.message).isEqualTo("duty.type.invalid")
        verify(dutyRepository, never()).save(any<Duty>())
    }

    @Test
    fun `duty update rejects a hidden duty type`() {
        val team = createTeam(1L)
        val member = createMember(1L).apply { this.team = team }
        val hiddenType = createDutyType(10L, "숨김근무", team).apply { hidden = true }
        val dto = DutyUpdateDto(2026, 7, 10, hiddenType.id, member.id!!)
        whenever(memberRepository.findMemberWithTeamForUpdate(member.id!!)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(hiddenType.id!!)).thenReturn(Optional.of(hiddenType))

        val exception = assertThrows<IllegalArgumentException> { dutyService.update(dto) }

        assertThat(exception.message).isEqualTo("duty.type.invalid")
        verify(dutyRepository, never()).save(any<Duty>())
    }

    @Test
    fun `duty batch update set all duties`() {
        // Given
        val memberId = 1L
        val dutyTypeId = 10L
        val member = createMember(memberId)
        val team = createTeam(1L)
        member.team = team
        val dutyType = createDutyType(dutyTypeId, "오전", team)
        val year = 2025
        val month = 1
        val yearMonth = YearMonth.of(year, month)
        val daysInMonth = yearMonth.lengthOfMonth()

        val dto = DutyBatchUpdateDto(
            year = year,
            month = month,
            dutyTypeId = dutyTypeId,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(dutyTypeId)).thenReturn(Optional.of(dutyType))
        whenever(dutyRepository.saveAll(any<List<Duty>>())).thenAnswer { it.arguments[0] }

        // When
        dutyService.update(dto)

        // Then
        verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(
            member,
            yearMonth.atDay(1),
            yearMonth.atEndOfMonth(),
        )
        verify(dutyRepository).saveAll(org.mockito.kotlin.argThat<List<Duty>> { list ->
            list.size == daysInMonth && list.all { it.dutyType == dutyType }
        })
        inOrder(memberRepository, dutyRepository) {
            verify(memberRepository).findMemberWithTeamForUpdate(memberId)
            verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(
                member,
                yearMonth.atDay(1),
                yearMonth.atEndOfMonth(),
            )
        }
    }

    @Test
    fun `duty batch update delete all duties if dutyTypeId is null`() {
        // Given
        val memberId = 1L
        val member = createMember(memberId)
        val team = createTeam(1L)
        member.team = team
        val dutyType = createDutyType(10L, "오전", team)
        val year = 2025
        val month = 1
        val yearMonth = YearMonth.of(year, month)

        val existingDuty = Duty(
            dutyDate = LocalDate.of(year, month, 1),
            dutyType = dutyType,
            member = member
        )

        val dto = DutyBatchUpdateDto(
            year = year,
            month = month,
            dutyTypeId = null,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyRepository.saveAll(any<List<Duty>>())).thenAnswer { it.arguments[0] }

        // When
        dutyService.update(dto)

        // Then
        verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(
            member,
            yearMonth.atDay(1),
            yearMonth.atEndOfMonth(),
        )
        verify(dutyRepository).saveAll(org.mockito.kotlin.argThat<List<Duty>> { list ->
            list.all { it.dutyType == null }
        })
    }

    @Test
    fun `duty batch update dutyTypeId if already exists`() {
        // Given
        val memberId = 1L
        val oldDutyTypeId = 10L
        val newDutyTypeId = 11L
        val member = createMember(memberId)
        val team = createTeam(1L)
        member.team = team
        val oldDutyType = createDutyType(oldDutyTypeId, "오전", team)
        val newDutyType = createDutyType(newDutyTypeId, "오후", team)
        val year = 2025
        val month = 1
        val yearMonth = YearMonth.of(year, month)

        val existingDuty = Duty(
            dutyDate = LocalDate.of(year, month, 1),
            dutyType = oldDutyType,
            member = member
        )

        val dto = DutyBatchUpdateDto(
            year = year,
            month = month,
            dutyTypeId = newDutyTypeId,
            memberId = memberId
        )

        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))
        whenever(dutyTypeRepository.findById(newDutyTypeId)).thenReturn(Optional.of(newDutyType))
        whenever(dutyRepository.saveAll(any<List<Duty>>())).thenAnswer { it.arguments[0] }

        // When
        dutyService.update(dto)

        // Then
        verify(dutyRepository).deleteDutiesByMemberAndDutyDateBetween(
            member,
            yearMonth.atDay(1),
            yearMonth.atEndOfMonth(),
        )
        verify(dutyRepository).saveAll(org.mockito.kotlin.argThat<List<Duty>> { list ->
            list.size == yearMonth.lengthOfMonth() && list.all { it.dutyType == newDutyType }
        })
    }

    @Test
    fun `reset override locks member before deleting duty`() {
        val memberId = 1L
        val member = createMember(memberId).apply { team = createTeam(1L) }
        val date = LocalDate.of(2026, 7, 10)
        whenever(memberRepository.findMemberWithTeamForUpdate(memberId)).thenReturn(Optional.of(member))

        dutyService.resetOverride(memberId, date)

        inOrder(memberRepository, dutyRepository) {
            verify(memberRepository).findMemberWithTeamForUpdate(memberId)
            verify(dutyRepository).deleteByMemberAndDutyDate(member, date)
        }
    }

}
