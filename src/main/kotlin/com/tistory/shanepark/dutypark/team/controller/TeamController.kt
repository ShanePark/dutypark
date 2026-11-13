package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarRequestDates
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyByShift
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamCreateDto
import com.tistory.shanepark.dutypark.team.domain.dto.MyTeamSummary
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.domain.enums.TeamNameCheckResult
import com.tistory.shanepark.dutypark.team.domain.enums.TeamNameCheckResult.*
import com.tistory.shanepark.dutypark.team.service.TeamService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/teams")
class TeamController(
    private val teamService: TeamService,
) {

    @PostMapping
    fun create(
        @Login loginMember: LoginMember,
        @RequestBody @Valid teamCreateDto: TeamCreateDto,
    ): TeamDto {
        return teamService.create(loginMember, teamCreateDto)
    }

    @PostMapping("/check")
    fun nameCheck(
        @Login loginMember: LoginMember,
        @RequestBody payload: Map<String, String>,
    ): TeamNameCheckResult {
        val name = payload["name"]?.trim().orEmpty()
        if (name.length < 2)
            return TOO_SHORT
        if (name.length > 20)
            return TOO_LONG
        if (teamService.isDuplicated(name))
            return DUPLICATED
        return OK
    }

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): TeamDto {
        return teamService.findByIdWithDutyTypes(id)
    }

    @GetMapping("/my")
    fun getMyTeamInfo(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int,
    ): MyTeamSummary {
        CalendarRequestDates.yearMonth(year, month)
        return teamService.myTeamSummary(
            loginMember = loginMember,
            year = year,
            month = month
        )
    }

    @DeleteMapping("/my/membership")
    fun leave(@Login loginMember: LoginMember) {
        teamService.leaveTeam(loginMember)
    }

    @GetMapping("/shift")
    fun shift(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam day: Int,
    ): List<DutyByShift> {
        return teamService.loadShift(loginMember = loginMember, localDate = CalendarRequestDates.date(year, month, day))
    }

}
