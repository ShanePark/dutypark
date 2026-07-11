package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternDetailsDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternDayDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternDutyTypeDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

@Service
@Transactional
class DutyPatternService(
    private val memberRepository: MemberRepository,
    private val patternRepository: MemberDutyPatternRepository,
    private val dutyRepository: DutyRepository,
    private val clock: Clock,
) {
    fun getMine(memberId: Long): DutyPatternDto {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        val team = member.team
            ?: return DutyPatternDto(false, "TEAM_REQUIRED", emptyList(), null)
        val visibleTypes = team.dutyTypes.filterNot { it.hidden }.sortedBy { it.position }
        val reason = "DUTY_TYPE_REQUIRED".takeIf { visibleTypes.isEmpty() }
        val dutyTypes = visibleTypes.map(::toDto)
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)
            ?.takeIf { it.team.id == team.id }
        val pattern = active?.let {
            DutyPatternDetailsDto(
                days = it.days
                    .sortedBy { day -> day.weekday.value }
                    .map { day -> DutyPatternDayDto(day.weekday, toDto(day.dutyType)) },
                holidayOff = it.holidayOff,
                effectiveFrom = it.effectiveFrom.toString(),
            )
        }
        return DutyPatternDto(reason == null, reason, dutyTypes, pattern)
    }

    @Transactional(timeout = 20)
    fun updateMine(memberId: Long, request: DutyPatternUpdateDto): DutyPatternDto {
        if (request.days.isEmpty()) {
            throw IllegalArgumentException("duty.pattern.weekdays.required")
        }
        if (request.days.map { it.weekday }.distinct().size != request.days.size) {
            throw IllegalArgumentException("duty.pattern.weekdays.duplicate")
        }
        val today = today()
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        val team = member.team ?: throw IllegalArgumentException("duty.pattern.team.required")
        val visibleTypesById = team.dutyTypes
            .filterNot { it.hidden }
            .associateBy { requireNotNull(it.id) }
        val dayTypes = request.days.associate { day ->
            val dutyType = if (day.dutyTypeId == null) {
                visibleTypesById.values.singleOrNull()
            } else {
                visibleTypesById[day.dutyTypeId]
            } ?: throw IllegalArgumentException("duty.pattern.dutyType.invalid")
            day.weekday to dutyType
        }
        val requestedDayTypeIds = dayTypes.mapValues { it.value.id }
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)
        if (
            active != null &&
            active.team.id == team.id &&
            active.dayTypeIds() == requestedDayTypeIds &&
            active.holidayOff == request.holidayOff
        ) {
            return getMine(memberId)
        }

        replaceCurrentPattern(member, today)
        dutyRepository.deleteAllByMemberAndDutyDateGreaterThanEqual(member, today)
        patternRepository.save(
            MemberDutyPattern(
                member = member,
                team = team,
                dayTypes = dayTypes,
                holidayOff = request.holidayOff,
                effectiveFrom = today,
            )
        )
        return getMine(memberId)
    }

    @Transactional(timeout = 20)
    fun deleteMine(memberId: Long) {
        val today = today()
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member)
            ?.takeIf { it.team.id == member.team?.id }
            ?: return
        dutyRepository.deleteAllByMemberAndDutyDateGreaterThanEqual(member, today)
        terminatePattern(active, today)
    }

    /** Team transfer/removal flows call this before changing member.team. */
    @Transactional(timeout = 20)
    fun terminateActivePattern(member: Member) {
        val today = today()
        val locked = memberRepository.findMemberWithTeamForUpdate(requireNotNull(member.id)).orElseThrow()
        dutyRepository.deleteAllByMemberAndDutyDateGreaterThanEqual(locked, today)
        terminateCurrentPattern(locked, today)
    }

    fun deleteHistoryForTeam(team: Team) {
        patternRepository.deleteAllByTeam(team)
    }

    private fun replaceCurrentPattern(member: Member, today: LocalDate) {
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member) ?: return
        if (active.effectiveFrom == today) {
            patternRepository.delete(active)
        } else {
            active.closeAt(today)
        }
    }

    private fun terminateCurrentPattern(member: Member, today: LocalDate) {
        val active = patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member) ?: return
        terminatePattern(active, today)
    }

    private fun terminatePattern(active: MemberDutyPattern, today: LocalDate) {
        if (active.effectiveFrom == today) {
            patternRepository.delete(active)
        } else {
            active.closeAt(today)
        }
    }

    private fun today(): LocalDate = LocalDate.now(clock.withZone(SEOUL))

    private fun toDto(dutyType: com.tistory.shanepark.dutypark.duty.domain.entity.DutyType) =
        DutyPatternDutyTypeDto(requireNotNull(dutyType.id), dutyType.name, dutyType.color)

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
