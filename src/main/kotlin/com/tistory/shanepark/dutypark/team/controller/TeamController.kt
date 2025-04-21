package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.domain.dto.MyTeamSummary
import com.tistory.shanepark.dutypark.team.service.TeamService
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyByShift
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.web.bind.annotation.*
import java.time.LocalDate
import java.time.YearMonth

@RestController
@RequestMapping("/api/teams")
class TeamController(
    private val teamService: TeamService,
) {

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
        return teamService.myTeamSummary(
            loginMember = loginMember,
            year = year,
            month = month
        )
    }

    @GetMapping("/shift")
    fun shift(
        @Login loginMember: LoginMember,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam day: Int,
    ): List<DutyByShift> {
        return teamService.loadShift(loginMember = loginMember, localDate = LocalDate.of(year, month, day))
    }

}
