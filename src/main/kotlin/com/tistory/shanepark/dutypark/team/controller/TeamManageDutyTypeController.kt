package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeVisibilityDto
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
        require(teamId == dutyTypeCreateDto.teamId) { "team.dutyType.teamMismatch" }
        checkCanManage(login = loginMember, teamId = dutyTypeCreateDto.teamId)
        dutyTypeService.addDutyType(dutyTypeCreateDto)
        log.info("DutyType created: teamId={}, name={}, by={}", dutyTypeCreateDto.teamId, dutyTypeCreateDto.name, loginMember.id)
    }

    @PatchMapping("/{teamId}/duty-types")
    @SlackNotification
    fun updateDutyType(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestBody @Valid dutyTypeUpdateDto: DutyTypeUpdateDto
    ) {
        val dutyType = dutyTypeService.findById(dutyTypeUpdateDto.id)
        require(teamId == dutyType.teamId) { "team.dutyType.teamMismatch" }
        checkCanManage(login = loginMember, teamId = dutyType.teamId)
        dutyTypeService.update(dutyTypeUpdateDto)
        log.info("DutyType updated: id={}, by={}", dutyTypeUpdateDto.id, loginMember.id)
    }

    @PatchMapping("/{teamId}/duty-types/swap-position")
    fun swapDutyTypePosition(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam id1: Long, @RequestParam id2: Long
    ) {
        val dutyType1 = dutyTypeService.findById(id1)
        val dutyType2 = dutyTypeService.findById(id2)
        require(dutyType1.teamId == dutyType2.teamId) { "team.dutyType.sameTeam.required" }
        require(teamId == dutyType1.teamId) { "team.dutyType.teamMismatch" }
        checkCanManage(login = loginMember, teamId = dutyType1.teamId)
        dutyTypeService.swapDutyTypePosition(id1, id2)
    }

    @PatchMapping("/{teamId}/duty-types/{id}/visibility")
    @SlackNotification
    fun updateVisibility(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @PathVariable id: Long,
        @RequestBody @Valid visibility: DutyTypeVisibilityDto,
    ) {
        val dutyType = dutyTypeService.findById(id)
        require(teamId == dutyType.teamId) { "team.dutyType.teamMismatch" }
        checkCanManage(login = loginMember, teamId = dutyType.teamId)
        dutyTypeService.updateVisibility(id, visibility.hidden)
        log.info("DutyType visibility updated: id={}, hidden={}, by={}", id, visibility.hidden, loginMember.id)
    }

    private fun checkCanManage(login: LoginMember, teamId: Long) {
        teamService.checkCanManage(login = login, teamId = teamId)
    }

}
