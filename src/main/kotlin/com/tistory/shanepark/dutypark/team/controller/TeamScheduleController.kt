package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.schedule.domain.dto.TeamScheduleDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamScheduleSaveDto
import com.tistory.shanepark.dutypark.team.service.TeamScheduleService
import com.tistory.shanepark.dutypark.team.service.TeamService
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.*
import java.util.*

@RestController
@RequestMapping("/api/teams/schedules")
class TeamScheduleController(
    private val teamScheduleService: TeamScheduleService,
    private val teamService: TeamService,
) {
    @GetMapping
    fun getSchedules(
        @Login login: LoginMember,
        @RequestParam teamId: Long,
        @RequestParam year: Int,
        @RequestParam month: Int,
    ): Array<List<TeamScheduleDto>> {
        checkCanRead(login = login, teamId = teamId)
        return teamScheduleService.findTeamSchedules(
            teamId = teamId,
            calendarView = CalendarView(year = year, month = month)
        )
    }

    @PostMapping
    fun saveSchedule(
        @Login login: LoginMember,
        @RequestBody @Validated saveDto: TeamScheduleSaveDto,
    ): TeamScheduleDto {
        checkCanManage(login = login, teamId = saveDto.teamId)
        if (saveDto.id == null) {
            return teamScheduleService.create(login = login, saveDto = saveDto)
        }
        return teamScheduleService.update(login = login, saveDto = saveDto)
    }

    @DeleteMapping("/{scheduleId}")
    fun deleteSchedule(
        @Login login: LoginMember,
        @PathVariable scheduleId: UUID,
    ) {
        val schedule = teamScheduleService.findById(scheduleId)
        checkCanManage(login = login, teamId = schedule.teamId)
        teamScheduleService.delete(id = scheduleId)
    }

    private fun checkCanRead(login: LoginMember, teamId: Long) {
        teamService.checkCanRead(login = login, teamId = teamId)
    }

    private fun checkCanManage(login: LoginMember, teamId: Long) {
        teamService.checkCanManage(login = login, teamId = teamId)
    }

}
