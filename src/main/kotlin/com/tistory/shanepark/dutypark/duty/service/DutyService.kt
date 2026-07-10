package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.OtherDutyResponse
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.LocalDate.of
import java.time.YearMonth

@Service
@Transactional
class DutyService(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService,
    private val memberService: MemberService,
    private val dutyResolver: DutyResolver,
    private val teamRepository: TeamRepository,
) {

    @Transactional(timeout = 20)
    fun update(dutyUpdateDto: DutyUpdateDto) {
        val member = memberRepository.findMemberWithTeamForUpdate(dutyUpdateDto.memberId).orElseThrow()
        val dutyType: DutyType? = dutyUpdateDto.dutyTypeId?.let {
            dutyTypeRepository.findById(it).orElseThrow()
        }
        validateDutyType(member, dutyType)

        val duty: Duty = dutyRepository.findByMemberAndDutyDate(
            member = member,
            dutyDate = of(dutyUpdateDto.year, dutyUpdateDto.month, dutyUpdateDto.day)
        ) ?: dutyRepository.save(
            Duty(
                member = member,
                dutyDate = YearMonth.of(dutyUpdateDto.year, dutyUpdateDto.month).atDay(dutyUpdateDto.day),
                dutyType = dutyType
            )
        )
        duty.dutyType = dutyType
        duty.teamId = member.team?.id
        duty.manualOverride = true
    }

    @Transactional(timeout = 20)
    fun update(dutyBatchUpdateDto: DutyBatchUpdateDto) {
        val member = memberRepository.findMemberWithTeamForUpdate(dutyBatchUpdateDto.memberId).orElseThrow()
        val dutyType: DutyType? = dutyBatchUpdateDto.dutyTypeId?.let {
            dutyTypeRepository.findById(it).orElseThrow()
        }
        validateDutyType(member, dutyType)

        val targetMonth = YearMonth.of(dutyBatchUpdateDto.year, dutyBatchUpdateDto.month)
        dutyRepository.deleteDutiesByMemberAndDutyDateBetween(
            member,
            targetMonth.atDay(1),
            targetMonth.atEndOfMonth(),
        )

        val duties = (1..targetMonth.lengthOfMonth())
            .map { day ->
                Duty(
                    member = member,
                    dutyDate = targetMonth.atDay(day),
                    dutyType = dutyType
                )
            }
        dutyRepository.saveAll(duties)
    }

    fun canEdit(loginMember: LoginMember, memberId: Long): Boolean {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()

        return member.isEquals(loginMember)
                || memberService.canManageTeam(loginMember = loginMember, team = member.team)
                || memberService.isManager(isManager = loginMember, target = member)
    }

    @Transactional(timeout = 20)
    fun getDuties(memberId: Long, year: Int, month: Int, loginMember: LoginMember?): List<DutyDto> {
        val preview = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, preview)

        val previewTeam = preview.team ?: return emptyList()
        val calendarView = CalendarView(year = year, month = month)
        val previewDuties = dutyResolver.resolve(preview, calendarView.dates)
        if (previewDuties.none { !it.persisted && it.source == DutySource.PATTERN }) {
            return previewDuties.map { it.toDto(previewTeam) }
        }

        teamRepository.findByIdForUpdate(requireNotNull(previewTeam.id)).orElseThrow()
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        val team = member.team ?: return emptyList()
        val resolvedDuties = dutyResolver.resolve(member, calendarView.dates)
        val automaticDuties = resolvedDuties
            .filter { !it.persisted && it.source == DutySource.PATTERN }
            .map { resolved ->
                Duty(
                    member = member,
                    dutyDate = resolved.date,
                    dutyType = resolved.dutyType,
                    teamId = resolved.sourceTeamId ?: team.id,
                    manualOverride = false,
                )
            }
        dutyRepository.saveAll(automaticDuties)

        return resolvedDuties.map { resolved ->
            resolved.toDto(team)
        }
    }

    @Transactional(timeout = 20)
    fun resetOverride(memberId: Long, date: LocalDate) {
        val member = memberRepository.findMemberWithTeamForUpdate(memberId).orElseThrow()
        dutyRepository.deleteByMemberAndDutyDate(member, date)
    }

    private fun validateDutyType(member: Member, dutyType: DutyType?) {
        if (dutyType == null) return
        if (dutyType.team.id != member.team?.id || dutyType.hidden) {
            throw IllegalArgumentException("duty.type.invalid")
        }
    }

    private fun ResolvedDuty.toDto(team: com.tistory.shanepark.dutypark.team.domain.entity.Team): DutyDto {
        val resolvedDutyType = dutyType
        if (resolvedDutyType == null) {
            return DutyDto.offDuty(date, team, source)
        }
        return DutyDto(
            year = date.year,
            month = date.monthValue,
            day = date.dayOfMonth,
            dutyType = resolvedDutyType.name,
            dutyColor = resolvedDutyType.color,
            isOff = false,
            dutyTypeId = resolvedDutyType.id,
            source = source,
        )
    }

    @Transactional(timeout = 25)
    fun getOtherDuties(
        loginMember: LoginMember,
        memberIds: List<Long>,
        year: Int, month: Int
    ): List<OtherDutyResponse> {
        val responsesByMemberId = memberIds.distinct().sorted().associateWith { id ->
            val member = memberRepository.findById(id).orElseThrow()
            val team = member.team ?: throw IllegalArgumentException("Member with id $id does not belong to any team")
            val duties =
                getDuties(memberId = id, year = year, month = month, loginMember = loginMember).map {
                    if (it.dutyType.isNullOrBlank()) {
                        it.copy(dutyType = team.defaultDutyName, dutyColor = team.defaultDutyColor)
                    } else it
                }
            OtherDutyResponse(
                memberId = member.id!!,
                name = member.name,
                hasProfilePhoto = member.hasProfilePhoto(),
                profilePhotoVersion = member.profilePhotoVersion,
                duties = duties
            )
        }
        return memberIds.map { requireNotNull(responsesByMemberId[it]) }
    }

}
