package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.TeamScheduleDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.repository.TeamScheduleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class TeamScheduleService(
    private val teamScheduleRepository: TeamScheduleRepository,
    private val teamRepository: TeamRepository,
    private val memberRepository: MemberRepository,
) {
    fun create(login: LoginMember, saveDto: TeamScheduleSaveDto): TeamScheduleDto {
        val author = memberRepository.findById(login.id).orElseThrow()
        val team = teamRepository.findById(saveDto.teamId).orElseThrow()
        val startDate = saveDto.startDateTime.toLocalDate()
        val sameDateStartSchedules = teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
            team,
            startDate.atStartOfDay(),
            startDate.atTime(23, 59, 59)
        )

        val schedule = TeamSchedule(
            team = team,
            createMember = author,
            content = saveDto.content,
            description = saveDto.description,
            startDateTime = saveDto.startDateTime,
            endDateTime = saveDto.endDateTime,
            position = sameDateStartSchedules.size
        )
        teamScheduleRepository.save(schedule)
        return TeamScheduleDto.ofSimple(schedule)
    }

    @Transactional(readOnly = true)
    fun findTeamSchedules(teamId: Long, calendarView: CalendarView): Array<List<TeamScheduleDto>> {
        val team = teamRepository.findById(teamId).orElseThrow()
        val schedules = teamScheduleRepository.findTeamSchedulesOfTeamRangeIn(
            team = team,
            start = calendarView.rangeFromDateTime,
            end = calendarView.rangeUntilDateTime,
        )
        val array = calendarView.makeCalendarArray<TeamScheduleDto>()
        schedules.map { TeamScheduleDto.of(calendar = calendarView, schedule = it) }
            .flatten()
            .sortedWith(compareBy({ it.position }, { it.startDateTime }))
            .forEach {
                if (!calendarView.isInRange(it.curDate)) {
                    return@forEach
                }
                val dayIndex = calendarView.getIndex(date = it.curDate)
                array[dayIndex] = array[dayIndex] + it
            }
        return array
    }

    @Transactional(readOnly = true)
    fun findById(id: UUID): TeamScheduleDto {
        val schedule = teamScheduleRepository.findById(id).orElseThrow()
        return TeamScheduleDto.ofSimple(schedule)
    }

    fun update(login: LoginMember, saveDto: TeamScheduleSaveDto): TeamScheduleDto {
        val author = memberRepository.findById(login.id).orElseThrow()
        val schedule = teamScheduleRepository.findById(saveDto.id!!).orElseThrow()
        schedule.update(saveDto = saveDto, updateMember = author)
        return TeamScheduleDto.ofSimple(schedule)
    }

    fun delete(id: UUID) {
        val teamSchedule = teamScheduleRepository.findById(id).orElseThrow()
        teamScheduleRepository.delete(teamSchedule)
    }

}
