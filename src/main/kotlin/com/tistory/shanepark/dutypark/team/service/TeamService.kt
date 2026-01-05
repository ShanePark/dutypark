package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyByShift
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.dto.SimpleMemberDto
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.*
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate

@Service
@Transactional
class TeamService(
    private val teamRepository: TeamRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val dutyRepository: DutyRepository,
    private val memberRepository: MemberRepository,
) {
    val log = logger()

    @Transactional(readOnly = true)
    fun findAllWithMemberCount(pageable: Pageable, keyword: String = ""): Page<SimpleTeamDto> {
        return teamRepository.findAllWithMemberCount(pageable = pageable, keyword = keyword)
    }

    @Transactional(readOnly = true)
    fun findByIdWithMembersAndDutyTypes(id: Long): TeamDto {
        val withMembers = teamRepository.findByIdWithMembers(id).orElseThrow()
        val withDutyTypes = teamRepository.findByIdWithDutyTypes(id).orElseThrow()

        return TeamDto.of(
            team = withMembers,
            members = withMembers.members,
            dutyTypes = withDutyTypes.dutyTypes,
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
        return teamRepository.findByName(name) != null
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

    fun changeTeamAdmin(teamId: Long, memberId: Long?) {
        val team = teamRepository.findById(teamId).orElseThrow()
        val member = memberId?.let { memberRepository.findById(memberId).orElseThrow() }

        team.changeAdmin(member)
        teamRepository.save(team)
    }

    fun addTeamManager(teamId: Long, memberId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        if (member.team != team) {
            throw IllegalStateException("Member does not belong to team")
        }
        if (team.isManager(memberId)) {
            log.info("Already a team manager, team: $team, member: $member")
            return
        }
        team.addManager(member)
    }

    fun removeTeamManager(teamId: Long, memberId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        if (member.team != team) {
            throw IllegalStateException("Member does not belong to team")
        }
        if (!team.isManager(memberId)) {
            log.info("Already not a team manager, team: $team, member: $member")
            return
        }
        team.removeManager(member)
    }

    fun updateDefaultDuty(teamId: Long, newDutyName: String?, newDutyColor: String?) {
        val team = teamRepository.findById(teamId).orElseThrow()
        if (newDutyColor != null) {
            team.defaultDutyColor = newDutyColor
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

        // OFF members: no duty record OR duty record with null dutyType
        val membersWithDutyType = dutyMemberMap.filter { (duty, _) -> duty.dutyType != null }.values.toSet()
        val offMembers = teamMembers.filterNot { m -> membersWithDutyType.contains(m) }

        val dutyTypes = dutyTypeRepository.findAllByTeam(team)
        val dutyTypeMembers = TeamDto.of(team, teamMembers, dutyTypes)
            .dutyTypes
            .map { dutyTypeDto ->
                val sourceMembers = dutyTypeDto.id?.let { id ->
                    dutyMemberMap.filter { (duty, _) -> duty.dutyType?.id == id }.values
                } ?: offMembers
                val members = sourceMembers
                    .map { member -> SimpleMemberDto(member.id!!, member.name, member.hasProfilePhoto()) }
                    .sortedBy { it.name }
                DutyByShift(dutyTypeDto, members)
            }
        return dutyTypeMembers
    }

    fun myTeamSummary(loginMember: LoginMember, year: Int, month: Int): MyTeamSummary {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val team = member.team ?: return MyTeamSummary(year = year, month = month)
        val teamDto = TeamDto.ofSimple(team)
        val calendarView = CalendarView(year = year, month = month)

        val days = mutableListOf<TeamDay>()
        for (cur in calendarView.dates) {
            val teamDay = TeamDay(
                year = cur.year,
                month = cur.monthValue,
                day = cur.dayOfMonth
            )
            days.add(teamDay)
        }

        return MyTeamSummary(
            year = year,
            month = month,
            team = teamDto,
            teamDays = days,
            isTeamManager = team.isManager(login = loginMember)
        )
    }

    fun checkCanManage(login: LoginMember, teamId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        if (login.isAdmin)
            return
        if (!team.isManager(login)) {
            throw AuthException("Member is not a team manager")
        }
    }

    fun checkCanAdmin(login: LoginMember, teamId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        if (login.isAdmin)
            return
        if (!team.isAdmin(login.id)) {
            throw AuthException("Member is not a team admin")
        }

    }

    fun checkCanRead(login: LoginMember, teamId: Long) {
        val team = teamRepository.findById(teamId).orElseThrow()
        if (login.isAdmin)
            return
        val member = memberRepository.findById(login.id).orElseThrow()
        if (member.team != team) {
            throw AuthException("Member is not a team member, team: $team, member: $member")
        }
    }

    fun updateWorkType(teamId: Long, workType: WorkType) {
        val team = teamRepository.findById(teamId).orElseThrow()
        team.workType = workType
    }

}
