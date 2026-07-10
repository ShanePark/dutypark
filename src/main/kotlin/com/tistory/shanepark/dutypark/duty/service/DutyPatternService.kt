package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternDetailsDto
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
                effectiveFrom = it.effectiveFrom.toString(),
            )
        }
        return DutyPatternDto(reason == null, reason, dutyType, pattern)
    }

    @Transactional(timeout = 20)
    fun updateMine(memberId: Long, request: DutyPatternUpdateDto): DutyPatternDto {
        if (request.weekdays.isEmpty()) {
            throw IllegalArgumentException("duty.pattern.weekdays.required")
        }
        val today = today()
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        val team = member.team ?: throw IllegalArgumentException("duty.pattern.team.required")
        val visibleTypes = team.dutyTypes.filterNot { it.hidden }
        if (visibleTypes.size != 1) {
            throw IllegalArgumentException("duty.pattern.singleDutyType.required")
        }

        replaceCurrentPattern(member, today)
        dutyRepository.deleteAllByMemberAndDutyDateGreaterThanEqual(member, today)
        patternRepository.save(
            MemberDutyPattern(
                member = member,
                team = team,
                dutyType = visibleTypes.single(),
                weekdays = request.weekdays.toMutableSet(),
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
        dutyRepository.deleteAllByMemberAndDutyDateGreaterThanEqual(member, today)
        terminateCurrentPattern(member, today)
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
        if (active.effectiveFrom == today) {
            patternRepository.delete(active)
        } else {
            active.closeAt(today)
        }
    }

    private fun today(): LocalDate = LocalDate.now(clock.withZone(SEOUL))

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
