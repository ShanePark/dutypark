package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.service.TeamService
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/team")
class TeamViewController(
    private val teamService: TeamService
) : ViewController() {

    @GetMapping
    fun myTeamPage(
        @Login loginMember: LoginMember,
        model: Model
    ): String {
        return layout(menu = "team/team-my", model = model)
    }

    @GetMapping("/manage/{teamId}")
    fun manageTeamPage(
        @Login loginMember: LoginMember,
        model: Model, @PathVariable teamId: Long
    ): String {
        teamService.checkCanManage(login = loginMember, teamId = teamId)
        return layout(menu = "team/team-manage", model = model)
    }

}
