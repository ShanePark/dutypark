package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.common.slack.annotation.SlackNotification
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.service.DutyTypeService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.service.TeamService
import jakarta.validation.Valid
import org.springframework.context.ApplicationContext
import org.springframework.data.domain.Pageable
import org.springframework.data.domain.Sort
import org.springframework.data.web.PageableDefault
import org.springframework.data.web.SortDefault
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

@RestController
@RequestMapping("/api/teams/manage")
class TeamManageController(
    private val teamService: TeamService,
    private val memberService: MemberService,
    private val teamRepository: TeamRepository,
    private val dutyTypeService: DutyTypeService,
    private val applicationContext: ApplicationContext,
) {
    private val log = logger()

    @GetMapping("/{teamId}")
    fun findById(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long
    ): TeamDto {
        checkCanManage(login = loginMember, teamId = teamId)
        return teamService.findByIdWithMembersAndDutyTypes(teamId)
    }

    @PutMapping("/{teamId}/admin")
    fun changeManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long?
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.changeTeamAdmin(teamId = teamId, memberId = memberId)
    }

    @PatchMapping("/{teamId}/batch-template")
    fun updateBatchTemplate(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam(name = "templateName", required = false) dutyBatchTemplate: DutyBatchTemplate?
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.updateBatchTemplate(teamId, dutyBatchTemplate)
    }

    @PostMapping("/{teamId}/duty")
    fun uploadBatchTemplate(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam(name = "file") file: MultipartFile,
        @RequestParam(name = "year") year: Int,
        @RequestParam(name = "month") month: Int
    ): DutyBatchTeamResult {
        checkCanManage(login = loginMember, teamId = teamId)
        val team = teamRepository.findById(teamId).orElseThrow()
        val batchTemplate = team.dutyBatchTemplate ?: throw IllegalArgumentException("templateName is required")
        val dutyBatchService = applicationContext.getBean(batchTemplate.batchServiceClass) as DutyBatchService
        return try {
            log.info("batch duty upload by $loginMember for team ${team.name}(${team.id}) year=$year, month=$month")
            dutyBatchService.batchUploadTeam(
                teamId = teamId,
                file = file,
                yearMonth = YearMonth.of(year, month)
            )
        } catch (e: DutyBatchException) {
            DutyBatchTeamResult.fail(e.message ?: "알 수 없는 원인으로 시간표 업로드 실패.")
        }
    }

    @PatchMapping("/{teamId}/default-duty")
    fun updateDefaultDuty(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam color: String,
        @RequestParam name: String,
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.updateDefaultDuty(teamId, name, color)
    }

    @PostMapping("/{teamId}/members")
    fun addMember(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.addMemberToTeam(teamId = teamId, memberId = memberId)
    }

    @DeleteMapping("/{teamId}/members")
    fun removeMember(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.removeMemberFromTeam(teamId, memberId)
    }

    @GetMapping("/members")
    fun members(
        @PageableDefault(page = 0, size = 10)
        @SortDefault(sort = ["name"], direction = Sort.Direction.ASC)
        page: Pageable,
        @RequestParam(required = false, defaultValue = "") keyword: String,
    ): PageResponse<MemberDto> {
        return PageResponse(memberService.searchMembersToInviteTeam(page = page, keyword = keyword))
    }


    /********************************************************************************
     * Manager
     ********************************************************************************/
    @PostMapping("/{teamId}/manager")
    fun addManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanAdmin(login = loginMember, teamId = teamId)
        teamService.addTeamManager(teamId = teamId, memberId = memberId)
    }

    @DeleteMapping("/{teamId}/manager")
    fun removeManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanAdmin(login = loginMember, teamId = teamId)
        teamService.removeTeamManager(teamId = teamId, memberId = memberId)
    }

    /********************************************************************************
     * Duty Types
     ********************************************************************************/

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

    private fun checkCanAdmin(login: LoginMember, teamId: Long) {
        teamService.checkCanAdmin(login = login, teamId = teamId)
    }

}
