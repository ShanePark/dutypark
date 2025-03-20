package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.repository.TeamScheduleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.util.*

@Service
@Transactional
class TeamScheduleService(
    private val teamScheduleRepository: TeamScheduleRepository,
    private val teamRepository: TeamRepository,
    private val memberRepository: MemberRepository,
) {
    fun create(loginMember: LoginMember, saveDto: TeamScheduleSaveDto) {
        val author = memberRepository.findById(loginMember.id).orElseThrow()
        val team = teamRepository.findById(saveDto.teamId).orElseThrow()
        val schedule = TeamSchedule(
            team = team,
            createMember = author,
            content = saveDto.content,
            description = saveDto.description,
            startDateTime = saveDto.startDateTime,
            endDateTime = saveDto.endDateTime,
        )
        teamScheduleRepository.save(schedule)
    }

    @Transactional(readOnly = true)
    fun findTeamSchedulesByRange(
        teamId: Long,
        startDateTime: LocalDateTime,
        endDateTime: LocalDateTime
    ): List<TeamSchedule> {
        val team = teamRepository.findById(teamId).orElseThrow()
        return teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
            team = team,
            start = startDateTime,
            end = endDateTime
        )
    }

    fun update(loginMember: LoginMember, saveDto: TeamScheduleSaveDto) {
        val author = memberRepository.findById(loginMember.id).orElseThrow()
        val schedule = teamScheduleRepository.findById(saveDto.id!!).orElseThrow()
        schedule.update(saveDto = saveDto, updateMember = author)
    }

    fun delete(teamScheduleId: UUID) {
        val teamSchedule = teamScheduleRepository.findById(teamScheduleId).orElseThrow()
        teamScheduleRepository.delete(teamSchedule)
    }

}
