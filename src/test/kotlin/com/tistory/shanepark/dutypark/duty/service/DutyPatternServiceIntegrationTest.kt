package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternMonthLockRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.service.TeamService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.DayOfWeek.FRIDAY
import java.time.DayOfWeek.MONDAY
import java.time.LocalDate
import java.time.YearMonth

class DutyPatternServiceIntegrationTest : DutyparkIntegrationTest() {
    @Autowired
    lateinit var dutyPatternService: DutyPatternService

    @Autowired
    lateinit var dutyResolver: DutyResolver

    @Autowired
    lateinit var dutyService: DutyService

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var patternRepository: MemberDutyPatternRepository

    @Autowired
    lateinit var monthLockRepository: MemberDutyPatternMonthLockRepository

    @Autowired
    lateinit var holidayRepository: HolidayRepository

    @Autowired
    lateinit var teamService: TeamService

    @Autowired
    lateinit var dutyTypeService: DutyTypeService

    @Autowired
    lateinit var holidayService: HolidayService

    @Test
    fun `pattern is calculated without creating duty rows and override can return to inheritance`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val month = YearMonth.now()
        val friday = daysOf(month).first { it.dayOfWeek == FRIDAY }

        val response = dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(FRIDAY), holidayOff = false),
        )

        assertThat(response.configurable).isTrue()
        assertThat(response.pattern?.weekdays).containsExactly(FRIDAY)
        val beforeRead = dutyRepository.count()
        val resolved = dutyResolver.resolve(member, friday)
        assertThat(resolved.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(resolved.source).isEqualTo(DutySource.PATTERN)
        dutyService.getDuties(member.id!!, month.year, month.monthValue, loginMember(member))
        assertThat(dutyRepository.count()).isEqualTo(beforeRead)

        dutyService.update(
            DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyTypeId = null, memberId = member.id!!)
        )
        assertThat(dutyResolver.resolve(member, friday).source).isEqualTo(DutySource.OVERRIDE)
        assertThat(dutyResolver.resolve(member, friday).dutyType).isNull()

        dutyService.resetOverride(member.id!!, friday)
        assertThat(dutyResolver.resolve(member, friday).source).isEqualTo(DutySource.PATTERN)
        assertThat(dutyResolver.resolve(member, friday).dutyType?.id).isEqualTo(dutyType.id)
    }

    @Test
    fun `changing a pattern locks a future month that contains a manual change`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.now().plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }

        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(MONDAY), holidayOff = false),
        )
        dutyService.update(
            DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!)
        )

        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(FRIDAY), holidayOff = false),
        )

        val locks = monthLockRepository.findAllByMemberAndYearMonthBetween(
            member,
            futureMonth.atDay(1),
            futureMonth.atDay(1),
        )
        assertThat(locks).hasSize(1)
        assertThat(dutyResolver.resolve(member, monday).source).isEqualTo(DutySource.LOCKED_PATTERN)
        assertThat(dutyResolver.resolve(member, monday).dutyType?.id).isEqualTo(dutyType.id)
        assertThat(dutyResolver.resolve(member, friday).source).isEqualTo(DutySource.OVERRIDE)
        dutyService.resetOverride(member.id!!, friday)
        assertThat(dutyResolver.resolve(member, friday).source).isEqualTo(DutySource.LOCKED_PATTERN)
        assertThat(dutyResolver.resolve(member, friday).dutyType).isNull()
        assertThat(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)).hasSize(2)
    }

    @Test
    fun `bulk resolver combines patterns and default off without per-member queries`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val other = TestData.member2.apply { team = member.team }
        memberRepository.save(other)
        val friday = daysOf(YearMonth.now()).first { it.dayOfWeek == FRIDAY }
        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(FRIDAY), holidayOff = false),
        )

        val resolved = dutyResolver.resolve(listOf(member, other), friday)

        assertThat(resolved[member.id]?.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(resolved[member.id]?.source).isEqualTo(DutySource.PATTERN)
        assertThat(resolved[other.id]?.dutyType).isNull()
        assertThat(resolved[other.id]?.source).isEqualTo(DutySource.DEFAULT_OFF)
    }

    @Test
    fun `holiday off policy can suppress or retain a patterned weekday`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val monday = daysOf(YearMonth.now()).first { it.dayOfWeek == MONDAY }
        holidayRepository.save(Holiday("테스트 공휴일", true, monday))

        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(MONDAY), holidayOff = true),
        )
        assertThat(dutyResolver.resolve(member, monday).dutyType).isNull()

        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(MONDAY), holidayOff = false),
        )
        assertThat(dutyResolver.resolve(member, monday).dutyType?.id).isEqualTo(dutyType.id)
    }

    @Test
    fun `matching overrides are removed instead of locking the month`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.now().plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(DutyUpdateDto(monday.year, monday.monthValue, monday.dayOfMonth, dutyType.id, member.id!!))

        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(FRIDAY), false))

        assertThat(monthLockRepository.existsByMemberAndTeamAndYearMonth(member, member.team!!, futureMonth.atDay(1))).isFalse()
        assertThat(dutyRepository.findByMemberAndDutyDate(member, monday)).isNull()
        assertThat(dutyResolver.resolve(member, monday).dutyType).isNull()
        assertThat(dutyResolver.resolve(member, friday).dutyType?.id).isEqualTo(dutyType.id)
    }

    @Test
    fun `manual change locks the current month when pattern changes`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val currentMonth = YearMonth.now()
        val monday = daysOf(currentMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(currentMonth).first { it.dayOfWeek == FRIDAY }
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!))

        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(FRIDAY), false))

        assertThat(monthLockRepository.existsByMemberAndTeamAndYearMonth(member, member.team!!, currentMonth.atDay(1))).isTrue()
        assertThat(dutyResolver.resolve(member, monday).source).isEqualTo(DutySource.LOCKED_PATTERN)
        assertThat(dutyResolver.resolve(member, monday).dutyType?.id).isEqualTo(dutyType.id)
        assertThat(dutyResolver.resolve(member, friday).source).isEqualTo(DutySource.OVERRIDE)
    }

    @Test
    fun `leaving a team terminates the active pattern and preserves history`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val teamId = requireNotNull(member.team?.id)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))

        teamService.removeMemberFromTeam(teamId, member.id!!)

        assertThat(
            patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)
        ).isNull()
        assertThat(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)).hasSize(1)
        assertThat(memberRepository.findById(member.id!!).orElseThrow().team).isNull()
    }

    @Test
    fun `deleting an empty team removes its pattern history before duty types`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val teamId = requireNotNull(member.team?.id)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))
        teamService.removeMemberFromTeam(teamId, member.id!!)

        teamService.delete(teamId)

        assertThat(teamRepository.findById(teamId)).isEmpty
        assertThat(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)).isEmpty()
    }

    @Test
    fun `operations without an active pattern do not create null month locks`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val team = requireNotNull(member.team)
        val futureMonth = YearMonth.now().plusMonths(1)
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!))

        dutyPatternService.deleteMine(member.id!!)
        dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "추가", "#654321"))
        teamService.removeMemberFromTeam(team.id!!, member.id!!)

        assertThat(monthLockRepository.findAllByMemberAndYearMonthBetween(
            member,
            futureMonth.atDay(1),
            futureMonth.atDay(1),
        )).isEmpty()
    }

    @Test
    fun `first pattern creation preserves a future manually edited month`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.now().plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!))

        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))

        assertThat(dutyResolver.resolve(member, monday).source).isEqualTo(DutySource.LOCKED_PATTERN)
        assertThat(dutyResolver.resolve(member, monday).dutyType).isNull()
        assertThat(dutyResolver.resolve(member, friday).source).isEqualTo(DutySource.OVERRIDE)
    }

    @Test
    fun `moving teams excludes old future locks overrides and duty types from personal and shift calculations`() {
        val (member, oldDutyType) = moveMemberToSingleDutyTypeTeam()
        val oldTeam = requireNotNull(member.team)
        val futureMonth = YearMonth.now().plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val tuesday = daysOf(futureMonth).first { it.dayOfWeek.value == 2 }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, oldDutyType.id, member.id!!))
        teamService.removeMemberFromTeam(oldTeam.id!!, member.id!!)

        val newTeam = teamRepository.save(Team("n-${System.nanoTime().toString().takeLast(12)}"))
        val newDutyType = newTeam.addDutyType("새근무", "#abcdef")
        dutyTypeRepository.saveAndFlush(newDutyType)
        teamService.addMemberToTeam(newTeam.id!!, member.id!!)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(tuesday.dayOfWeek), false))

        assertThat(member.team?.id).isEqualTo(newTeam.id)
        assertThat(monthLockRepository.findAllByMemberAndYearMonthBetween(member, futureMonth.atDay(1), futureMonth.atDay(1))
            .map { it.team.id }).containsOnly(oldTeam.id)
        assertThat(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)
            .filter { it.effectiveUntilExclusive == null }.map { it.team.id }).containsExactly(newTeam.id)
        assertThat(dutyResolver.resolve(member, monday).dutyType).isNull()
        assertThat(dutyResolver.resolve(member, tuesday).dutyType?.id).isEqualTo(newDutyType.id)
        assertThat(dutyResolver.resolve(member, friday).dutyType).isNull()
        val shifts = teamService.loadShift(loginMember(member), monday)
        assertThat(shifts.flatMap { it.members }.map { it.id }).containsExactly(member.id)
        assertThat(shifts.map { it.dutyType.id }).doesNotContain(oldDutyType.id)
    }

    @Test
    fun `locked month baseline does not change when holiday data changes`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.now().plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        holidayService.resetHolidayInfo()
        holidayRepository.save(Holiday("데이터 존재", false, futureMonth.atDay(1)))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))
        dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(FRIDAY), false))
        assertThat(dutyResolver.resolve(member, monday).dutyType?.id).isEqualTo(dutyType.id)

        holidayService.resetHolidayInfo()
        holidayRepository.save(Holiday("새 임시공휴일", true, monday))

        assertThat(dutyResolver.resolve(member, monday).source).isEqualTo(DutySource.LOCKED_PATTERN)
        assertThat(dutyResolver.resolve(member, monday).dutyType?.id).isEqualTo(dutyType.id)
    }

    @Test
    fun `only differing future months are locked while matching months are cleaned`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val first = YearMonth.now().plusMonths(1)
        val second = first.plusMonths(1)
        val third = second.plusMonths(1)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        listOf(first, third).forEach { month ->
            val friday = daysOf(month).first { it.dayOfWeek == FRIDAY }
            dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!))
        }
        val matchingMonday = daysOf(second).first { it.dayOfWeek == MONDAY }
        dutyService.update(
            DutyUpdateDto(
                matchingMonday.year,
                matchingMonday.monthValue,
                matchingMonday.dayOfMonth,
                dutyType.id,
                member.id!!,
            )
        )

        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(FRIDAY), false))

        val team = member.team!!
        assertThat(monthLockRepository.existsByMemberAndTeamAndYearMonth(member, team, first.atDay(1))).isTrue()
        assertThat(monthLockRepository.existsByMemberAndTeamAndYearMonth(member, team, second.atDay(1))).isFalse()
        assertThat(monthLockRepository.existsByMemberAndTeamAndYearMonth(member, team, third.atDay(1))).isTrue()
        assertThat(dutyRepository.findByMemberAndDutyDate(member, matchingMonday)).isNull()
    }

    @Test
    fun `pattern does not resume when duty type count returns from two to one`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val team = member.team!!
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))

        val added = dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "추가", "#654321"))
        dutyTypeRepository.saveAndFlush(added)
        dutyTypeService.updateVisibility(added.id!!, true)

        assertThat(patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)).isNull()
        assertThat(dutyPatternService.getMine(member.id!!).configurable).isTrue()
        assertThat(dutyPatternService.getMine(member.id!!).pattern).isNull()
    }

    @Test
    fun `hidden duty type is rejected for new edits but retained by old override and locked snapshot`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.now().plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        val tuesday = daysOf(futureMonth).first { it.dayOfWeek.value == 2 }
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(DutyUpdateDto(friday.year, friday.monthValue, friday.dayOfMonth, dutyType.id, member.id!!))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(FRIDAY), false))
        dutyTypeService.updateVisibility(dutyType.id!!, true)

        assertThrows<IllegalArgumentException> {
            dutyService.update(DutyUpdateDto(tuesday.year, tuesday.monthValue, tuesday.dayOfMonth, dutyType.id, member.id!!))
        }
        val locked = dutyResolver.resolve(member, monday)
        val override = dutyResolver.resolve(member, friday)
        assertThat(locked.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(locked.dutyType?.name).isEqualTo(dutyType.name)
        assertThat(locked.dutyType?.color).isEqualTo(dutyType.color)
        assertThat(override.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(override.dutyType?.name).isEqualTo(dutyType.name)
        assertThat(override.dutyType?.color).isEqualTo(dutyType.color)
    }

    private fun moveMemberToSingleDutyTypeTeam(): Pair<com.tistory.shanepark.dutypark.member.domain.entity.Member, DutyType> {
        val team = teamRepository.save(Team("p-${System.nanoTime().toString().takeLast(12)}"))
        val dutyType = team.addDutyType("근무", "#123456")
        dutyTypeRepository.saveAndFlush(dutyType)
        val member = TestData.member
        member.team = team
        val savedMember = memberRepository.save(member)
        return savedMember to dutyType
    }

    private fun daysOf(month: YearMonth): List<LocalDate> =
        (1..month.lengthOfMonth()).map(month::atDay)
}
