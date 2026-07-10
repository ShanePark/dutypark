package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.*
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPatternMonthLock
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternMonthLockRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

@Service
@Transactional
class DutyPatternService(
    private val memberRepository: MemberRepository,
    private val patternRepository: MemberDutyPatternRepository,
    private val monthLockRepository: MemberDutyPatternMonthLockRepository,
    private val dutyRepository: DutyRepository,
    private val dutyResolver: DutyResolver,
    private val clock: Clock,
) {
    fun getMine(memberId: Long): DutyPatternDto {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        val team = member.team
            ?: return DutyPatternDto(false, "TEAM_REQUIRED", null, null)
        val visibleTypes = team.dutyTypes.filterNot { it.hidden }
        val reason = when (visibleTypes.size) {
            0 -> "DUTY_TYPE_REQUIRED"
            1 -> null
            else -> "SINGLE_DUTY_TYPE_REQUIRED"
        }
        val dutyType = visibleTypes.singleOrNull()?.let {
            DutyPatternDutyTypeDto(requireNotNull(it.id), it.name, it.color)
        }
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)
            ?.takeIf { it.team.id == team.id }
        val pattern = active?.let {
            DutyPatternDetailsDto(
                weekdays = it.weekdays.toSet(),
                holidayOff = it.holidayOff,
                effectiveFrom = YearMonth.from(it.effectiveFrom).toString(),
            )
        }
        return DutyPatternDto(reason == null, reason, dutyType, pattern)
    }

    fun updateMine(memberId: Long, request: DutyPatternUpdateDto): DutyPatternDto {
        if (request.weekdays.isEmpty()) {
            throw IllegalArgumentException("duty.pattern.weekdays.required")
        }
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        val team = member.team ?: throw IllegalArgumentException("duty.pattern.team.required")
        val visibleTypes = team.dutyTypes.filterNot { it.hidden }
        if (visibleTypes.size != 1) {
            throw IllegalArgumentException("duty.pattern.singleDutyType.required")
        }
        val currentMonth = currentMonth()
        replaceCurrentPattern(member, currentMonth)
        patternRepository.save(
            MemberDutyPattern(
                member = member,
                team = team,
                dutyType = visibleTypes.single(),
                weekdays = request.weekdays.toMutableSet(),
                holidayOff = request.holidayOff,
                effectiveFrom = currentMonth.atDay(1),
            )
        )
        return getMine(memberId)
    }

    fun deleteMine(memberId: Long) {
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        terminateCurrentPattern(member, currentMonth())
    }

    /** Team duty-type visibility/count changes can call this before/after the change. */
    fun terminateActivePatternsForTeam(team: Team) {
        memberRepository.findMembersByTeam(team).sortedBy { it.id }.forEach { member ->
            val locked = memberRepository.findMemberWithTeamForUpdate(requireNotNull(member.id)).orElseThrow()
            terminateCurrentPattern(locked, currentMonth())
        }
    }

    /** Team transfer/removal flows can call this before changing member.team. */
    fun terminateActivePattern(member: Member) {
        val locked = memberRepository.findMemberWithTeamForUpdate(requireNotNull(member.id)).orElseThrow()
        terminateCurrentPattern(locked, currentMonth())
    }

    /** Team deletion must remove locks first because they reference pattern history. */
    fun deleteHistoryForTeam(team: Team) {
        monthLockRepository.deleteAllByTeam(team)
        patternRepository.deleteAllByTeam(team)
    }

    private fun replaceCurrentPattern(member: Member, currentMonth: YearMonth) {
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)
        preserveManuallyChangedMonths(member, active, currentMonth)
        active?.closeAt(currentMonth.atDay(1))
    }

    private fun terminateCurrentPattern(member: Member, currentMonth: YearMonth) {
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member) ?: return
        preserveManuallyChangedMonths(member, active, currentMonth)
        active.closeAt(currentMonth.atDay(1))
    }

    private fun preserveManuallyChangedMonths(
        member: Member,
        previousPattern: MemberDutyPattern?,
        fromMonth: YearMonth,
    ) {
        val currentTeam = member.team ?: return
        val lockTeam = previousPattern?.team ?: currentTeam
        val lastOverrideDate = dutyRepository.findTopByMemberOrderByDutyDateDesc(member)?.dutyDate ?: return
        val lastMonth = YearMonth.from(lastOverrideDate)
        if (lastMonth < fromMonth) return

        generateSequence(fromMonth) { current ->
            current.plusMonths(1).takeIf { it <= lastMonth }
        }.forEach { month ->
            val monthStart = month.atDay(1)
            if (monthLockRepository.existsByMemberAndTeamAndYearMonth(member, lockTeam, monthStart)) return@forEach
            val overrides = dutyRepository.findAllByMemberAndDutyDateBetween(member, monthStart, month.atEndOfMonth())
                .filter { it.teamId == lockTeam.id }
            if (overrides.isEmpty()) return@forEach
            val dates = (1..month.lengthOfMonth()).map(month::atDay)
            val expected = dutyResolver.resolvePattern(previousPattern, dates)
            val differs = overrides.any { override ->
                override.dutyType?.id != expected[override.dutyDate]?.id
            }
            if (differs) {
                val baselineWorkDates = expected.filterValues { it != null }.keys.toMutableSet()
                monthLockRepository.save(
                    MemberDutyPatternMonthLock(
                        member,
                        lockTeam,
                        monthStart,
                        previousPattern,
                        baselineWorkDates,
                    )
                )
            } else {
                dutyRepository.deleteAll(overrides)
            }
        }
    }

    private fun currentMonth(): YearMonth =
        YearMonth.from(LocalDate.now(clock.withZone(SEOUL)))

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
