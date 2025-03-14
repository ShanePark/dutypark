package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyByShift
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.dto.SimpleMemberDto
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.*
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth

@Service
@Transactional
class TeamService(
    private val teamRepository: TeamRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val dutyRepository: DutyRepository,
    private val memberRepository: MemberRepository
) {

    @Transactional(readOnly = true)
    fun findAllWithMemberCount(pageable: Pageable): Page<SimpleTeamDto> {
        return teamRepository.findAllWithMemberCount(pageable)
    }

    @Transactional(readOnly = true)
    fun findByIdWithMembersAndDutyTypes(id: Long): TeamDto {
        val withMembers = teamRepository.findByIdWithMembers(id).orElseThrow()
        val withDutyTypes = teamRepository.findByIdWithDutyTypes(id).orElseThrow()

        return TeamDto.of(
            team = withMembers,
            members = withMembers.members,
            dutyTypes = withDutyTypes.dutyTypes
        )
    }

    @Transactional(readOnly = true)
    fun findByIdWithDutyTypes(id: Long): TeamDto {
        val withDutyTypes = teamRepository.findByIdWithDutyTypes(id).orElseThrow()
        return TeamDto.of(
            team = withDutyTypes,
            members = emptyList(),
            dutyTypes = withDutyTypes.dutyTypes
        )
    }

    fun create(teamCreateDto: TeamCreateDto): TeamDto {
        Team(teamCreateDto.name).let {
            it.description = teamCreateDto.description
            teamRepository.save(it)
            return TeamDto.ofSimple(it)
        }
    }

    fun delete(id: Long) {
        val team = teamRepository.findById(id).orElseThrow()
        if (team.members.isNotEmpty()) {
            throw IllegalStateException("team has members")
        }

        dutyRepository.deleteAllByDutyTypeIn(team.dutyTypes)
        teamRepository.deleteById(id)
    }

    fun isDuplicated(name: String): Boolean {
        teamRepository.findByName(name).let {
            return it != null
        }
    }

    fun addMemberToTeam(teamId: Long, memberId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        if (member.team != null) {
            throw IllegalStateException("The member already belongs to team")
        }
        team.addMember(member)
    }

    fun removeMemberFromTeam(teamId: Long, memberId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        if (member.team != team) {
            throw IllegalStateException("Member does not belong to team")
        }
        team.removeMember(member)
    }

    fun changeManager(teamId: Long, memberId: Long?) {
        val team = teamRepository.findById(teamId).orElseThrow()
        val member = memberId?.let { memberRepository.findById(memberId).orElseThrow() }

        team.changeManager(member)
        teamRepository.save(team)
    }

    fun updateDefaultDuty(teamId: Long, newDutyName: String?, newDutyColor: String?) {
        val team = teamRepository.findById(teamId).orElseThrow()
        if (newDutyColor != null) {
            team.defaultDutyColor = Color.valueOf(newDutyColor)
        }
        if (newDutyName != null) {
            team.defaultDutyName = newDutyName
        }
    }

    fun updateBatchTemplate(teamId: Long, dutyBatchTemplate: DutyBatchTemplate?) {
        val team = teamRepository.findById(teamId).orElseThrow()
        team.dutyBatchTemplate = dutyBatchTemplate
    }

    fun loadShift(loginMember: LoginMember, localDate: LocalDate): List<DutyByShift> {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val team = member.team ?: return emptyList()
        return loadShift(team = team, localDate = localDate)
    }

    private fun loadShift(team: Team, localDate: LocalDate): List<DutyByShift> {
        val teamMembers = memberRepository.findMembersByTeam(team)

        val dutyMemberMap = dutyRepository.findByDutyDateAndMemberIn(localDate, teamMembers)
            .associateBy({ it }, { it.member })
        val offMembers = teamMembers.filterNot { m -> dutyMemberMap.containsValue(m) }

        val dutyTypes = dutyTypeRepository.findAllByTeam(team)
        val dutyTypeMembers = TeamDto.of(team, teamMembers, dutyTypes)
            .dutyTypes
            .map { dutyTypeDto ->
                val sourceMembers = dutyTypeDto.id?.let { id ->
                    dutyMemberMap.filter { (duty, _) -> duty.dutyType.id == id }.values
                } ?: offMembers
                val members = sourceMembers
                    .map { member -> SimpleMemberDto(member.id, member.name) }
                    .sortedBy { it.name }
                DutyByShift(dutyTypeDto, members)
            }
        return dutyTypeMembers
    }

    fun myTeamSummary(loginMember: LoginMember, yearMonth: YearMonth): MyTeamSummary {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val team = member.team ?: return MyTeamSummary(yearMonth = yearMonth)
        val teamDto = TeamDto.ofSimple(team)
        val calendarView = CalendarView(yearMonth)

        val days = mutableListOf<TeamDay>()
        for (cur in calendarView.getRangeDate()) {
            val teamDay = TeamDay(
                year = cur.year,
                month = cur.monthValue,
                day = cur.dayOfMonth
            )
            days.add(teamDay)
        }

        return MyTeamSummary(
            yearMonth = yearMonth,
            team = teamDto,
            teamDays = days
        )
    }

}
