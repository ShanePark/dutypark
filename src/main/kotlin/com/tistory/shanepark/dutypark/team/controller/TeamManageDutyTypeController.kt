package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyTypeService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.service.TeamService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/teams/manage")
class TeamManageDutyTypeController(
    private val teamService: TeamService,
    private val dutyTypeService: DutyTypeService,
) {
    private val log = logger()

    @PostMapping("/{teamId}/duty-types")
    @SlackNotification
    fun addDutyType(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestBody @Valid dutyTypeCreateDto: DutyTypeCreateDto
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        dutyTypeService.addDutyType(dutyTypeCreateDto)
        log.info("DutyType $dutyTypeCreateDto created by $loginMember")
    }

    @PatchMapping("/{teamId}/duty-types")
    @SlackNotification
    fun updateDutyType(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestBody @Valid dutyTypeUpdateDto: DutyTypeUpdateDto
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        dutyTypeService.update(dutyTypeUpdateDto)
        log.info("DutyType $dutyTypeUpdateDto updated by $loginMember")
    }

    @PatchMapping("/{teamId}/duty-types/swap-position")
    fun swapDutyTypePosition(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam id1: Long, @RequestParam id2: Long
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        dutyTypeService.swapDutyTypePosition(id1, id2)
    }

    @DeleteMapping("/{teamId}/duty-types/{id}")
    @SlackNotification
    fun delete(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @PathVariable id: Long
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        dutyTypeService.delete(id)
        log.info("DutyType $id deleted by $loginMember")
    }

    private fun checkCanManage(login: LoginMember, teamId: Long) {
        teamService.checkCanManage(login = login, teamId = teamId)
    }

}
