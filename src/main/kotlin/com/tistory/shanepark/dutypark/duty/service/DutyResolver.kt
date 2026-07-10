package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternMonthLockRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

data class ResolvedDuty(
    val date: LocalDate,
    val dutyType: DutyType?,
    val source: DutySource,
)

@Service
@Transactional(readOnly = true)
class DutyResolver(
    private val dutyRepository: DutyRepository,
    private val patternRepository: MemberDutyPatternRepository,
    private val monthLockRepository: MemberDutyPatternMonthLockRepository,
    private val holidayService: HolidayService,
    private val clock: Clock,
) {
    fun resolve(member: Member, dates: Collection<LocalDate>): List<ResolvedDuty> {
        if (dates.isEmpty()) return emptyList()
        val sortedDates = dates.distinct().sorted()
        val currentMonth = currentMonth()
        val overrides = dutyRepository.findAllByMemberAndDutyDateBetween(member, sortedDates.first(), sortedDates.last())
            .filter { isTeamApplicable(member, it.teamId, it.dutyDate, currentMonth) }
            .associateBy { it.dutyDate }
        val monthStarts = sortedDates.map { YearMonth.from(it).atDay(1) }
        val locks = monthLockRepository.findAllByMemberAndYearMonthBetween(
            member,
            monthStarts.min(),
            monthStarts.max(),
        ).groupBy { it.yearMonth }
            .mapValues { (monthStart, candidates) -> selectLock(member, monthStart, candidates, currentMonth) }
            .mapNotNull { (monthStart, lock) -> lock?.let { monthStart to it } }
            .toMap()
        val patterns = patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)
        val needsHolidays = sortedDates.any { date ->
            val lock = locks[YearMonth.from(date).atDay(1)]
            val effectivePattern = if (lock != null) null else patterns.firstOrNull {
                it.appliesOn(date) && isTeamApplicable(member, it.team.id, date, currentMonth)
            }
            effectivePattern?.holidayOff == true
        }
        val holidayDates = holidayDates(sortedDates, needsHolidays)

        return sortedDates.map { date ->
            val override = overrides[date]
            if (override != null) {
                return@map ResolvedDuty(date, override.dutyType, DutySource.OVERRIDE)
            }

            val lock = locks[YearMonth.from(date).atDay(1)]
            if (lock != null) {
                return@map ResolvedDuty(
                    date,
                    dutyTypeFor(lock, date),
                    DutySource.LOCKED_PATTERN,
                )
            }

            val pattern = patterns.firstOrNull {
                it.appliesOn(date) && isTeamApplicable(member, it.team.id, date, currentMonth)
            }
            if (pattern != null) {
                ResolvedDuty(date, dutyTypeFor(pattern, date, holidayDates), DutySource.PATTERN)
            } else {
                ResolvedDuty(date, null, DutySource.DEFAULT_OFF)
            }
        }
    }

    fun resolve(member: Member, date: LocalDate): ResolvedDuty = resolve(member, listOf(date)).single()

    fun resolve(members: Collection<Member>, date: LocalDate): Map<Long, ResolvedDuty> {
        if (members.isEmpty()) return emptyMap()
        val memberIds = members.mapNotNull { it.id }.toSet()
        val membersById = members.associateBy { requireNotNull(it.id) }
        val currentMonth = currentMonth()
        val overrides = dutyRepository.findByDutyDateAndMemberIn(date, members.toList())
            .filter { isTeamApplicable(it.member, it.teamId, date, currentMonth) }
            .associateBy { requireNotNull(it.member.id) }
        val monthStart = YearMonth.from(date).atDay(1)
        val locks = monthLockRepository.findAllByMemberInAndYearMonth(members, monthStart)
            .groupBy { requireNotNull(it.member.id) }
            .mapNotNull { (memberId, candidates) ->
                selectLock(requireNotNull(membersById[memberId]), monthStart, candidates, currentMonth)
                    ?.let { memberId to it }
            }.toMap()
        val patterns = patternRepository.findAllByMemberInOrderByEffectiveFromDescIdDesc(members)
        val patternsByMember = patterns.groupBy { requireNotNull(it.member.id) }
        val needsHolidays = memberIds.any { memberId ->
            val lock = locks[memberId]
            val effectivePattern = if (lock != null) {
                null
            } else {
                patternsByMember[memberId].orEmpty().firstOrNull {
                    it.appliesOn(date) && isTeamApplicable(requireNotNull(membersById[memberId]), it.team.id, date, currentMonth)
                }
            }
            effectivePattern?.holidayOff == true
        }
        val holidayDates = holidayDates(listOf(date), needsHolidays)

        return memberIds.associateWith { memberId ->
            val override = overrides[memberId]
            if (override != null) {
                return@associateWith ResolvedDuty(date, override.dutyType, DutySource.OVERRIDE)
            }
            val lock = locks[memberId]
            if (lock != null) {
                return@associateWith ResolvedDuty(
                    date,
                    dutyTypeFor(lock, date),
                    DutySource.LOCKED_PATTERN,
                )
            }
            val pattern = patternsByMember[memberId].orEmpty().firstOrNull {
                it.appliesOn(date) && isTeamApplicable(requireNotNull(membersById[memberId]), it.team.id, date, currentMonth)
            }
            if (pattern != null) {
                ResolvedDuty(date, dutyTypeFor(pattern, date, holidayDates), DutySource.PATTERN)
            } else {
                ResolvedDuty(date, null, DutySource.DEFAULT_OFF)
            }
        }
    }

    fun resolvePattern(
        pattern: MemberDutyPattern?,
        dates: Collection<LocalDate>,
    ): Map<LocalDate, DutyType?> {
        if (dates.isEmpty()) return emptyMap()
        val sortedDates = dates.distinct().sorted()
        val holidayDates = holidayDates(sortedDates, pattern?.holidayOff == true)
        return sortedDates.associateWith { dutyTypeFor(pattern, it, holidayDates) }
    }

    private fun dutyTypeFor(
        pattern: MemberDutyPattern?,
        date: LocalDate,
        holidayDates: Set<LocalDate>,
    ): DutyType? {
        if (pattern == null || date.dayOfWeek !in pattern.weekdays) return null
        if (pattern.holidayOff && date in holidayDates) return null
        return pattern.dutyType
    }

    private fun dutyTypeFor(
        lock: com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPatternMonthLock,
        date: LocalDate,
    ): DutyType? {
        if (date !in lock.baselineWorkDates) return null
        return lock.pattern?.dutyType
    }

    private fun holidayDates(
        dates: List<LocalDate>,
        required: Boolean,
    ): Set<LocalDate> {
        if (!required) return emptySet()
        return dates.map(YearMonth::from).distinct().flatMap { yearMonth ->
            holidayService.findHolidays(CalendarView(yearMonth.year, yearMonth.monthValue))
                .asSequence()
                .flatMap { it.asSequence() }
                .filter { it.isHoliday }
                .map { it.localDate }
                .toList()
        }.toSet()
    }

    private fun selectLock(
        member: Member,
        monthStart: LocalDate,
        candidates: List<com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPatternMonthLock>,
        currentMonth: YearMonth,
    ): com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPatternMonthLock? {
        if (YearMonth.from(monthStart) >= currentMonth) {
            return candidates.firstOrNull { it.team.id == member.team?.id }
        }
        return candidates.maxByOrNull { it.id ?: Long.MIN_VALUE }
    }

    private fun isTeamApplicable(
        member: Member,
        sourceTeamId: Long?,
        date: LocalDate,
        currentMonth: YearMonth,
    ): Boolean {
        if (YearMonth.from(date) < currentMonth) return true
        return sourceTeamId != null && sourceTeamId == member.team?.id
    }

    private fun currentMonth(): YearMonth =
        YearMonth.from(LocalDate.now(clock.withZone(SEOUL)))

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
