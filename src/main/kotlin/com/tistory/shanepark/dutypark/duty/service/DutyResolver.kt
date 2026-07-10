package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
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
    val persisted: Boolean = false,
    val sourceTeamId: Long? = null,
)

@Service
@Transactional
class DutyResolver(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val patternRepository: MemberDutyPatternRepository,
    private val holidayService: HolidayService,
    private val clock: Clock,
) {
    fun resolve(member: Member, dates: Collection<LocalDate>): List<ResolvedDuty> {
        if (dates.isEmpty()) return emptyList()
        val sortedDates = dates.distinct().sorted()
        val today = today()
        val overrides = dutyRepository.findAllByMemberAndDutyDateBetween(member, sortedDates.first(), sortedDates.last())
            .filter { isTeamApplicable(member, it.teamId, it.dutyDate, today) }
            .associateBy { it.dutyDate }
        val patterns = patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)
        val automaticDutyTypes = automaticDutyTypes(listOf(member))
        val needsHolidays = sortedDates.any { date ->
            val effectivePattern = patterns.firstOrNull {
                it.appliesOn(date) && isTeamApplicable(member, it.team.id, date, today)
            }
            effectivePattern?.holidayOff == true && effectiveDutyType(
                member,
                effectivePattern,
                date,
                today,
                automaticDutyTypes,
            ) != null
        }
        val holidayDates = holidayDates(sortedDates, needsHolidays)

        return sortedDates.map { date ->
            val override = overrides[date]
            if (override != null) {
                return@map ResolvedDuty(
                    date = date,
                    dutyType = override.dutyType,
                    source = if (override.manualOverride) DutySource.OVERRIDE else DutySource.PATTERN,
                    persisted = true,
                    sourceTeamId = override.teamId,
                )
            }

            val pattern = patterns.firstOrNull {
                it.appliesOn(date) && isTeamApplicable(member, it.team.id, date, today)
            }
            val dutyType = pattern?.let {
                effectiveDutyType(member, it, date, today, automaticDutyTypes)
            }
            if (pattern != null && dutyType != null) {
                ResolvedDuty(
                    date = date,
                    dutyType = dutyTypeFor(pattern, dutyType, date, holidayDates),
                    source = DutySource.PATTERN,
                    sourceTeamId = pattern.team.id,
                )
            } else if (pattern != null) {
                ResolvedDuty(date, null, DutySource.PATTERN_PAUSED, sourceTeamId = pattern.team.id)
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
        val today = today()
        val overrides = dutyRepository.findByDutyDateAndMemberIn(date, members.toList())
            .filter { isTeamApplicable(it.member, it.teamId, date, today) }
            .associateBy { requireNotNull(it.member.id) }
        val patterns = patternRepository.findAllByMemberInOrderByEffectiveFromDescIdDesc(members)
        val patternsByMember = patterns.groupBy { requireNotNull(it.member.id) }
        val automaticDutyTypes = automaticDutyTypes(members)
        val needsHolidays = memberIds.any { memberId ->
            val effectivePattern = patternsByMember[memberId].orEmpty().firstOrNull {
                it.appliesOn(date) && isTeamApplicable(requireNotNull(membersById[memberId]), it.team.id, date, today)
            }
            effectivePattern?.holidayOff == true && effectiveDutyType(
                requireNotNull(membersById[memberId]),
                effectivePattern,
                date,
                today,
                automaticDutyTypes,
            ) != null
        }
        val holidayDates = holidayDates(listOf(date), needsHolidays)

        return memberIds.associateWith { memberId ->
            val override = overrides[memberId]
            if (override != null) {
                return@associateWith ResolvedDuty(
                    date = date,
                    dutyType = override.dutyType,
                    source = if (override.manualOverride) DutySource.OVERRIDE else DutySource.PATTERN,
                    persisted = true,
                    sourceTeamId = override.teamId,
                )
            }
            val pattern = patternsByMember[memberId].orEmpty().firstOrNull {
                it.appliesOn(date) && isTeamApplicable(requireNotNull(membersById[memberId]), it.team.id, date, today)
            }
            val member = requireNotNull(membersById[memberId])
            val dutyType = pattern?.let {
                effectiveDutyType(member, it, date, today, automaticDutyTypes)
            }
            if (pattern != null && dutyType != null) {
                ResolvedDuty(
                    date = date,
                    dutyType = dutyTypeFor(pattern, dutyType, date, holidayDates),
                    source = DutySource.PATTERN,
                    sourceTeamId = pattern.team.id,
                )
            } else if (pattern != null) {
                ResolvedDuty(date, null, DutySource.PATTERN_PAUSED, sourceTeamId = pattern.team.id)
            } else {
                ResolvedDuty(date, null, DutySource.DEFAULT_OFF)
            }
        }
    }

    private fun dutyTypeFor(
        pattern: MemberDutyPattern,
        dutyType: DutyType,
        date: LocalDate,
        holidayDates: Set<LocalDate>,
    ): DutyType? {
        if (date.dayOfWeek !in pattern.weekdays) return null
        if (pattern.holidayOff && date in holidayDates) return null
        return dutyType
    }

    private fun automaticDutyTypes(members: Collection<Member>): Map<Long, DutyType> {
        val teams = members.mapNotNull { it.team }.distinctBy { it.id }
        if (teams.isEmpty()) return emptyMap()
        return dutyTypeRepository.findAllByTeamInAndHiddenFalse(teams)
            .groupBy { requireNotNull(it.team.id) }
            .mapNotNull { (teamId, dutyTypes) -> dutyTypes.singleOrNull()?.let { teamId to it } }
            .toMap()
    }

    private fun effectiveDutyType(
        member: Member,
        pattern: MemberDutyPattern,
        date: LocalDate,
        today: LocalDate,
        automaticDutyTypes: Map<Long, DutyType>,
    ): DutyType? {
        if (date.isBefore(today)) return pattern.dutyType
        val patternTeamId = pattern.team.id
        if (patternTeamId == null || patternTeamId != member.team?.id) return null
        return automaticDutyTypes[patternTeamId]
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

    private fun isTeamApplicable(
        member: Member,
        sourceTeamId: Long?,
        date: LocalDate,
        today: LocalDate,
    ): Boolean {
        if (date.isBefore(today)) return true
        return sourceTeamId != null && sourceTeamId == member.team?.id
    }

    private fun today(): LocalDate = LocalDate.now(clock.withZone(SEOUL))

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
