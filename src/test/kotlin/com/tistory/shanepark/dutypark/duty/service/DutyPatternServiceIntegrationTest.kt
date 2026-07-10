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
import java.time.DayOfWeek.SUNDAY
import java.time.DayOfWeek.WEDNESDAY
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
    fun `partially populated calendar fills only missing dates and preserves manual work and off overrides`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val targetMonth = YearMonth.from(today()).plusMonths(2)
        val view = CalendarView(targetMonth.year, targetMonth.monthValue)
        val manualWorkDate = view.dates.first { it.dayOfWeek == WEDNESDAY }
        val manualOffDate = view.dates.first { it.dayOfWeek == MONDAY }
        val existingAutomaticDate = view.dates.first { it.dayOfWeek == FRIDAY }
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyRepository.saveAll(
            listOf(
                Duty(manualWorkDate, dutyType, member, manualOverride = true),
                Duty(manualOffDate, null, member, manualOverride = true),
                Duty(existingAutomaticDate, null, member, manualOverride = false),
            )
        )

        val result = dutyService.getDuties(
            member.id!!,
            targetMonth.year,
            targetMonth.monthValue,
            loginMember(member),
        )

        val persisted = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(result).hasSize(CalendarView.SIZE)
        assertThat(persisted).hasSize(CalendarView.SIZE)
        val manualWork = dutyRepository.findByMemberAndDutyDate(member, manualWorkDate)
        assertThat(manualWork?.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(manualWork?.manualOverride).isTrue()
        val manualOff = dutyRepository.findByMemberAndDutyDate(member, manualOffDate)
        assertThat(manualOff?.dutyType).isNull()
        assertThat(manualOff?.manualOverride).isTrue()
        val existingAutomatic = dutyRepository.findByMemberAndDutyDate(member, existingAutomaticDate)
        assertThat(existingAutomatic?.dutyType).isNull()
        assertThat(existingAutomatic?.manualOverride).isFalse()
        assertThat(result.single { it.year == manualWorkDate.year && it.month == manualWorkDate.monthValue && it.day == manualWorkDate.dayOfMonth }.source)
            .isEqualTo(DutySource.OVERRIDE)
        assertThat(result.single { it.year == existingAutomaticDate.year && it.month == existingAutomaticDate.monthValue && it.day == existingAutomaticDate.dayOfMonth }.source)
            .isEqualTo(DutySource.PATTERN)
    }

    @Test
    fun `current month lookup materializes only dates on or after pattern effective date`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val today = today()
        val currentMonth = YearMonth.from(today)
        val view = CalendarView(currentMonth.year, currentMonth.monthValue)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(today.dayOfWeek), false))

        val result = dutyService.getDuties(
            member.id!!,
            currentMonth.year,
            currentMonth.monthValue,
            loginMember(member),
        )

        val persisted = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(persisted.map { it.dutyDate })
            .containsExactlyInAnyOrderElementsOf(view.dates.filterNot { it.isBefore(today) })
        assertThat(persisted).allMatch { !it.manualOverride }
        assertThat(result.filter { LocalDate.of(it.year, it.month, it.day).isBefore(today) })
            .allMatch { it.source == DutySource.DEFAULT_OFF }
        val todayDuty = result.single {
            it.year == today.year && it.month == today.monthValue && it.day == today.dayOfMonth
        }
        assertThat(todayDuty.source).isEqualTo(DutySource.PATTERN)
        assertThat(todayDuty.isOff).isFalse()
    }

    @Test
    fun `calendar materialization covers leap day and remains idempotent`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val leapMonth = generateSequence(YearMonth.from(today()).plusMonths(1)) { it.plusMonths(1) }
            .first { it.isLeapYear && it.monthValue == 2 }
        val leapDay = leapMonth.atDay(29)
        val view = CalendarView(leapMonth.year, leapMonth.monthValue)
        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(leapDay.dayOfWeek, SUNDAY), false),
        )

        repeat(2) {
            dutyService.getDuties(member.id!!, leapMonth.year, leapMonth.monthValue, loginMember(member))
        }

        val persisted = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(persisted).hasSize(CalendarView.SIZE)
        assertThat(persisted.map { it.dutyDate }).containsExactlyInAnyOrderElementsOf(view.dates)
        assertThat(dutyRepository.findByMemberAndDutyDate(member, leapDay)?.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(persisted.filter { it.dutyDate.dayOfWeek !in setOf(leapDay.dayOfWeek, SUNDAY) })
            .allMatch { it.dutyType == null }
    }

    @Test
    fun `calendar materialization crosses December and January without gaps`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val december = generateSequence(YearMonth.from(today()).plusMonths(1)) { it.plusMonths(1) }
            .first { it.monthValue == 12 }
        val view = CalendarView(december.year, december.monthValue)
        assertThat(view.startDate.year).isEqualTo(december.year)
        assertThat(view.endDate.year).isEqualTo(december.year + 1)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY, FRIDAY), false))

        dutyService.getDuties(member.id!!, december.year, december.monthValue, loginMember(member))

        val persisted = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(persisted).hasSize(CalendarView.SIZE)
        assertThat(persisted.map { it.dutyDate }).containsExactlyInAnyOrderElementsOf(view.dates)
        assertThat(persisted).anyMatch { it.dutyDate.year == december.year + 1 }
        assertThat(persisted.filter { it.dutyType != null }.map { it.dutyDate.dayOfWeek }.toSet())
            .containsExactlyInAnyOrder(MONDAY, FRIDAY)
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
    fun `pattern replacement closes yesterday rule exactly at today boundary`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val today = today()
        val oldPattern = MemberDutyPattern(
            member = member,
            team = member.team!!,
            dutyType = dutyType,
            weekdays = mutableSetOf(today.minusDays(1).dayOfWeek),
            holidayOff = false,
            effectiveFrom = today.minusMonths(2),
        )
        patternRepository.saveAndFlush(oldPattern)

        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(today.dayOfWeek), false),
        )

        val patterns = patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)
        assertThat(patterns).hasSize(2)
        assertThat(patterns.single { it.id == oldPattern.id }.effectiveUntilExclusive).isEqualTo(today)
        val yesterdayDuty = dutyResolver.resolve(member, today.minusDays(1))
        assertThat(yesterdayDuty.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(yesterdayDuty.source).isEqualTo(DutySource.PATTERN)
        val todayDuty = dutyResolver.resolve(member, today)
        assertThat(todayDuty.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(todayDuty.source).isEqualTo(DutySource.PATTERN)
    }

    @Test
    fun `replacing a pattern twice on the same day keeps only the last version`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))

        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(FRIDAY), true))

        val patterns = patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)
        assertThat(patterns).hasSize(1)
        assertThat(patterns.single().weekdays).containsExactly(FRIDAY)
        assertThat(patterns.single().holidayOff).isTrue()
        assertThat(patterns.single().effectiveFrom).isEqualTo(today())
    }

    @Test
    fun `retrying an unchanged pattern update preserves future manual duties`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val request = DutyPatternUpdateDto(setOf(MONDAY, FRIDAY), true)
        val futureDate = today().plusMonths(2)
        dutyPatternService.updateMine(member.id!!, request)
        val manualDuty = dutyRepository.saveAndFlush(
            Duty(futureDate, dutyType, member, manualOverride = true)
        )

        dutyPatternService.updateMine(member.id!!, request)

        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureDate)?.id).isEqualTo(manualDuty.id)
        assertThat(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)).hasSize(1)
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
    fun `deleting when no pattern exists preserves manually entered future duties`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureDate = today().plusMonths(2)
        val manualDuty = dutyRepository.saveAndFlush(
            Duty(futureDate, dutyType, member, manualOverride = true)
        )

        dutyPatternService.deleteMine(member.id!!)

        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureDate)?.id).isEqualTo(manualDuty.id)
        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureDate)?.manualOverride).isTrue()
    }

    @Test
    fun `retrying pattern deletion does not delete duties entered after the first deletion`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureDate = today().plusMonths(2)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyRepository.saveAndFlush(Duty(futureDate, dutyType, member, manualOverride = true))

        dutyPatternService.deleteMine(member.id!!)
        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureDate)).isNull()
        val newlyEntered = dutyRepository.saveAndFlush(
            Duty(futureDate, dutyType, member, manualOverride = true)
        )

        dutyPatternService.deleteMine(member.id!!)

        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureDate)?.id).isEqualTo(newlyEntered.id)
        assertThat(dutyRepository.findByMemberAndDutyDate(member, futureDate)?.manualOverride).isTrue()
    }

    @Test
    fun `lookup after pattern deletion does not recreate deleted future duties`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val targetMonth = YearMonth.from(today()).plusMonths(1)
        val view = CalendarView(targetMonth.year, targetMonth.monthValue)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.getDuties(member.id!!, targetMonth.year, targetMonth.monthValue, loginMember(member))
        assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)).isNotEmpty()

        dutyPatternService.deleteMine(member.id!!)
        val result = dutyService.getDuties(
            member.id!!,
            targetMonth.year,
            targetMonth.monthValue,
            loginMember(member),
        )

        assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)).isEmpty()
        assertThat(result).allMatch { it.source == DutySource.DEFAULT_OFF && it.isOff }
    }

    @Test
    fun `resetting a manual off override restores automatic work from the pattern`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val targetMonth = YearMonth.from(today()).plusMonths(1)
        val monday = daysOf(targetMonth).first { it.dayOfWeek == MONDAY }
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.update(DutyUpdateDto(monday.year, monday.monthValue, monday.dayOfMonth, null, member.id!!))
        val manualOff = dutyResolver.resolve(member, monday)
        assertThat(manualOff.source).isEqualTo(DutySource.OVERRIDE)
        assertThat(manualOff.dutyType).isNull()

        dutyService.resetOverride(member.id!!, monday)
        val result = dutyService.getDuties(
            member.id!!,
            targetMonth.year,
            targetMonth.monthValue,
            loginMember(member),
        )

        val inherited = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(inherited?.dutyType?.id).isEqualTo(dutyType.id)
        assertThat(inherited?.manualOverride).isFalse()
        assertThat(result.single { it.year == monday.year && it.month == monday.monthValue && it.day == monday.dayOfMonth }.source)
            .isEqualTo(DutySource.PATTERN)
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

        val pausedResult = dutyService.getDuties(
            member.id!!,
            futureMonth.year,
            futureMonth.monthValue,
            loginMember(member),
        )

        assertThat(dutyRepository.findByMemberAndDutyDate(member, manualDate)?.manualOverride).isTrue()
        assertThat(
            dutyRepository.findAllByMemberAndDutyDateBetween(member, today(), futureMonth.atEndOfMonth())
                .filter { !it.manualOverride }
        ).isEmpty()
        val missingMonday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY && it != manualDate }
        assertThat(dutyResolver.resolve(member, missingMonday).source).isEqualTo(DutySource.PATTERN_PAUSED)
        assertThat(pausedResult.single {
            it.year == manualDate.year && it.month == manualDate.monthValue && it.day == manualDate.dayOfMonth
        }.source).isEqualTo(DutySource.OVERRIDE)
        assertThat(pausedResult.single {
            it.year == missingMonday.year && it.month == missingMonday.monthValue && it.day == missingMonday.dayOfMonth
        }.source).isEqualTo(DutySource.PATTERN_PAUSED)
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
    fun `holiday off applies to adjacent month dates shown in the calendar padding`() {
        val (member, _) = moveMemberToSingleDutyTypeTeam()
        val firstFuture = YearMonth.from(today()).plusMonths(1)
        val targetMonth = if (firstFuture.monthValue == 12) firstFuture.plusMonths(1) else firstFuture
        val view = CalendarView(targetMonth.year, targetMonth.monthValue)
        assertThat(YearMonth.from(view.startDate)).isNotEqualTo(targetMonth)
        assertThat(YearMonth.from(view.endDate)).isNotEqualTo(targetMonth)
        holidayService.resetHolidayInfo()
        holidayRepository.saveAll(
            listOf(
                Holiday("이전 달 공휴일", true, view.startDate),
                Holiday("다음 달 공휴일", true, view.endDate),
            )
        )
        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(view.startDate.dayOfWeek, view.endDate.dayOfWeek), true),
        )

        dutyService.getDuties(member.id!!, targetMonth.year, targetMonth.monthValue, loginMember(member))

        assertThat(dutyRepository.findByMemberAndDutyDate(member, view.startDate)?.manualOverride).isFalse()
        assertThat(dutyRepository.findByMemberAndDutyDate(member, view.startDate)?.dutyType).isNull()
        assertThat(dutyRepository.findByMemberAndDutyDate(member, view.endDate)?.manualOverride).isFalse()
        assertThat(dutyRepository.findByMemberAndDutyDate(member, view.endDate)?.dutyType).isNull()
    }

    @Test
    fun `holiday off disabled still materializes work on a selected holiday`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.from(today()).plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        holidayService.resetHolidayInfo()
        holidayRepository.save(Holiday("테스트 공휴일", true, monday))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))

        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        val generated = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(generated?.manualOverride).isFalse()
        assertThat(generated?.dutyType?.id).isEqualTo(dutyType.id)
    }

    @Test
    fun `manual work override wins over holiday off pattern`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.from(today()).plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        holidayService.resetHolidayInfo()
        holidayRepository.save(Holiday("테스트 공휴일", true, monday))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))
        dutyService.update(
            DutyUpdateDto(monday.year, monday.monthValue, monday.dayOfMonth, dutyType.id, member.id!!)
        )

        val result = dutyService.getDuties(
            member.id!!,
            futureMonth.year,
            futureMonth.monthValue,
            loginMember(member),
        )

        val persisted = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(persisted?.manualOverride).isTrue()
        assertThat(persisted?.dutyType?.id).isEqualTo(dutyType.id)
        val resolved = result.single {
            it.year == monday.year && it.month == monday.monthValue && it.day == monday.dayOfMonth
        }
        assertThat(resolved.source).isEqualTo(DutySource.OVERRIDE)
        assertThat(resolved.isOff).isFalse()
    }

    @Test
    fun `non-holiday observance does not suppress selected workday`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val futureMonth = YearMonth.from(today()).plusMonths(1)
        val monday = daysOf(futureMonth).first { it.dayOfWeek == MONDAY }
        holidayService.resetHolidayInfo()
        holidayRepository.save(Holiday("휴일 아님", false, monday))
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))

        dutyService.getDuties(member.id!!, futureMonth.year, futureMonth.monthValue, loginMember(member))

        assertThat(dutyRepository.findByMemberAndDutyDate(member, monday)?.dutyType?.id).isEqualTo(dutyType.id)
    }

    @Test
    fun `holiday reset invalidates only future automatic duties and allows rematerialization`() {
        val (member, dutyType) = moveMemberToSingleDutyTypeTeam()
        val targetMonth = YearMonth.from(today()).plusMonths(1)
        val view = CalendarView(targetMonth.year, targetMonth.monthValue)
        val manualDate = targetMonth.atDay(15)
        dutyPatternService.updateMine(member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        dutyService.getDuties(member.id!!, targetMonth.year, targetMonth.monthValue, loginMember(member))
        dutyService.update(
            DutyUpdateDto(manualDate.year, manualDate.monthValue, manualDate.dayOfMonth, dutyType.id, member.id!!)
        )

        holidayService.resetHolidayInfo()

        val afterReset = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(afterReset).hasSize(1)
        assertThat(afterReset.single().dutyDate).isEqualTo(manualDate)
        assertThat(afterReset.single().manualOverride).isTrue()

        dutyService.getDuties(member.id!!, targetMonth.year, targetMonth.monthValue, loginMember(member))
        val rematerialized = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
        assertThat(rematerialized).hasSize(CalendarView.SIZE)
        assertThat(rematerialized.single { it.dutyDate == manualDate }.manualOverride).isTrue()
        assertThat(rematerialized.filter { it.dutyDate != manualDate }).allMatch { !it.manualOverride }
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

    @Test
    fun `past pattern keeps its hidden historical duty type while current pattern is paused`() {
        val (member, oldDutyType) = moveMemberToSingleDutyTypeTeam()
        val team = member.team!!
        val pastMonth = YearMonth.from(today()).minusMonths(2)
        val oldPattern = MemberDutyPattern(
            member = member,
            team = team,
            dutyType = oldDutyType,
            weekdays = mutableSetOf(MONDAY),
            holidayOff = false,
            effectiveFrom = pastMonth.atDay(1),
        ).also { it.closeAt(today()) }
        patternRepository.saveAndFlush(oldPattern)
        oldDutyType.hidden = true
        dutyTypeRepository.saveAndFlush(oldDutyType)
        val replacement = dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "대체1", "#abcdef"))
        dutyTypeRepository.saveAndFlush(replacement)
        val second = dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "대체2", "#fedcba"))
        dutyTypeRepository.saveAndFlush(second)

        dutyService.getDuties(member.id!!, pastMonth.year, pastMonth.monthValue, loginMember(member))

        val monday = daysOf(pastMonth).first { it.dayOfWeek == MONDAY }
        val historical = dutyRepository.findByMemberAndDutyDate(member, monday)
        assertThat(historical?.dutyType?.id).isEqualTo(oldDutyType.id)
        assertThat(historical?.manualOverride).isFalse()
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
