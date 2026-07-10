package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.Clock
import java.time.DayOfWeek.FRIDAY
import java.time.DayOfWeek.MONDAY
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

class DutyPatternServiceIntegrationTest : DutyparkIntegrationTest() {
    @Autowired lateinit var dutyPatternService: DutyPatternService
    @Autowired lateinit var dutyResolver: DutyResolver
    @Autowired lateinit var dutyService: DutyService
    @Autowired lateinit var dutyRepository: DutyRepository
    @Autowired lateinit var patternRepository: MemberDutyPatternRepository
    @Autowired lateinit var dutyTypeService: DutyTypeService
    @Autowired lateinit var holidayRepository: HolidayRepository
    @Autowired lateinit var holidayService: HolidayService
    @Autowired lateinit var clock: Clock

    @Test
    fun `month lookup materializes every missing pattern date without overwriting a manual duty`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val targetMonth = YearMonth.from(today()).plusMonths(1)
        val manualDate = targetMonth.atDay(15)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(
            DutyUpdateDto(manualDate.year, manualDate.monthValue, manualDate.dayOfMonth, null, member.id!!)
        )

        val firstResult = dutyService.getDuties(
            member.id!!,
            targetMonth.year,
            targetMonth.monthValue,
            loginMember(member),
        )

        val view = CalendarView(targetMonth.year, targetMonth.monthValue)
        val persisted = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(firstResult).hasSize(CalendarView.SIZE)
        assertThat(persisted).hasSize(CalendarView.SIZE)
        assertThat(persisted.single { it.dutyDate == manualDate }.manualOverride).isTrue()
        assertThat(persisted.single { it.dutyDate == manualDate }.dutyType).isNull()
        assertThat(persisted.filter { it.dutyDate != manualDate }).allMatch { !it.manualOverride }
        assertThat(persisted.filter { it.dutyDate.dayOfWeek == MONDAY && it.dutyDate != manualDate })
            .allMatch { it.dutyType != null }

        dutyService.getDuties(member.id!!, targetMonth.year, targetMonth.monthValue, loginMember(member))
        assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate))
            .hasSize(CalendarView.SIZE)
    }

    @Test
    fun `pattern change deletes every duty from today and applies the new weekdays from today`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val today = today()
        val yesterday = today.minusDays(1)
        val futureMonth = YearMonth.from(today).plusMonths(1)
        val futureManual = futureMonth.atDay(15)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyRepository.save(Duty(yesterday, dutyType, member, manualOverride = true))
        dutyService.update(
            DutyUpdateDto(futureManual.year, futureManual.monthValue, futureManual.dayOfMonth, dutyType.id, member.id!!)
        )
        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        val updated = dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(FRIDAY), false),
        )

        assertThat(updated.pattern?.effectiveFrom).isEqualTo(today.toString())
        assertThat(dutyRepository.findByMemberAndDutyDate(member, yesterday)).isNotNull()
        assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, today, futureMonth.atEndOfMonth())).isEmpty()

        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val friday = daysOf(futureMonth).first { it.dayOfWeek == FRIDAY }
        assertThat(dutyRepository.findByMemberAndDutyDate(member, monday)?.dutyType).isNull()
        assertThat(dutyRepository.findByMemberAndDutyDate(member, friday)?.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureManual)?.manualOverride).isFalse()
    }

    @Test
    fun `deleting a pattern removes every future duty but keeps past duties`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val today = today()
        val yesterday = today.minusDays(1)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyRepository.save(Duty(yesterday, dutyType, member))
        dutyRepository.save(Duty(today.plusDays(2), dutyType, member))

        dutyPatternService.deleteMine(member.id!!)

        assertThat(dutyRepository.findByMemberAndDutyDate(member, yesterday)).isNotNull()
        assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, today, today.plusYears(1))).isEmpty()
        assertThat(patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)).isNull()
    }

    @Test
    fun `multiple duty types pause materialization and remove only automatic future duties`() {
        val (member, originalType) = moveMemberToSingleDutyTypeTeam()
        val team = member.team!!
        val futureMonth = YearMonth.from(today()).plusMonths(1)
        val manualDate = futureMonth.atDay(15)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(
            DutyUpdateDto(manualDate.year, manualDate.monthValue, manualDate.dayOfMonth, originalType.id, member.id!!)
        )
        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        val added = dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "추가", "#654321"))
        dutyTypeRepository.saveAndFlush(added)

        assertThat(dutyRepository.findByMemberAndDutyDate(member, manualDate)?.manualOverride).isTrue()
        assertThat(
            dutyRepository.findAllByMemberAndDutyDateBetween(member, today(), futureMonth.atEndOfMonth())
                .filter { !it.manualOverride }
        ).isEmpty()
        val missingMonday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY && it != manualDate }
        assertThat(dutyResolver.resolve(member, missingMonday).source).isEqualTo(DutySource.PATTERN_PAUSED)
        assertThat(dutyPatternService.getMine(member.id!!).pattern).isNotNull()
    }

    @Test
    fun `pattern resumes with the remaining single type and materializes missing dates`() {
        val (member, originalType) = moveMemberToSingleDutyTypeTeam()
        val team = member.team!!
        val futureMonth = YearMonth.from(today()).plusMonths(1)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        val replacement = dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "교체", "#abcdef"))
        dutyTypeRepository.saveAndFlush(replacement)
        dutyTypeService.updateVisibility(originalType.id!!, true)

        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        val generated = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(generated?.manualOverride).isFalse()
        assertThat(generated?.dutyType?.id).isEqualTo(replacement.id)
        assertThat(dutyPatternService.getMine(member.id!!).pattern?.weekdays).containsExactly(MONDAY)
    }

    @Test
    fun `holiday off is materialized as an automatic off duty`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.from(today()).plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        holidayService.resetHolidayInfo()
        holidayRepository.save(Holiday("테스트 공휴일", true, monday))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))

        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        val generated = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(generated?.manualOverride).isFalse()
        assertThat(generated?.dutyType).isNull()
    }

    @Test
    fun `lookup without a pattern does not create duty rows`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.from(today()).plusMonths(1)

        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        val view = CalendarView(futureMonth.year, futureMonth.monthValue)
        assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)).isEmpty()
    }

    @Test
    fun `materializing a past pattern keeps the team that owned that pattern`() {
        val (member, oldDutyType) = moveMemberToSingleDutyTypeTeam()
        val oldTeam = member.team!!
        val pastMonth = YearMonth.from(today()).minusMonths(2)
        val oldPattern = MemberDutyPattern(
            member = member,
            team = oldTeam,
            dutyType = oldDutyType,
            weekdays = mutableSetOf(MONDAY),
            holidayOff = false,
            effectiveFrom = pastMonth.atDay(1),
        ).also { it.closeAt(today()) }
        patternRepository.saveAndFlush(oldPattern)

        val newTeam = teamRepository.save(Team("new-${System.nanoTime().toString().takeLast(12)}"))
        dutyTypeRepository.saveAndFlush(newTeam.addDutyType("새근무", "#654321"))
        member.team = newTeam
        memberRepository.saveAndFlush(member)

        dutyService.getDuties(member.id!!, pastMonth.year, pastMonth.monthValue, loginMember(member))

        val monday = daysOf(pastMonth).first { it.dayOfWeek == MONDAY }
        val generated = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(generated?.manualOverride).isFalse()
        assertThat(generated?.teamId).isEqualTo(oldTeam.id)
        assertThat(generated?.dutyType?.id).isEqualTo(oldDutyType.id)
    }

    private fun moveMemberToSingleDutyTypeTeam(): Pair<com.tistory.shanepark.dutypark.member.domain.entity.Member, DutyType> {
        val team = teamRepository.save(Team("p-${System.nanoTime().toString().takeLast(12)}"))
        val dutyType = team.addDutyType("근무", "#123456")
        dutyTypeRepository.saveAndFlush(dutyType)
        val member = TestData.member
        member.team = team
        return memberRepository.save(member) to dutyType
    }

    private fun today(): LocalDate = LocalDate.now(clock.withZone(ZoneId.of("Asia/Seoul")))

    private fun daysOf(month: YearMonth): List<LocalDate> =
        (1..month.lengthOfMonth()).map(month::atDay)
}
