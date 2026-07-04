package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberInviteCandidateDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.service.TeamService
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
        log.info("Team admin changed: teamId={}, newAdminId={}, by={}", teamId, memberId, loginMember.id)
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

    @PatchMapping("/{teamId}/work-type")
    fun updateWorkType(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam workType: WorkType,
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.updateWorkType(teamId, workType)
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
        val batchTemplate = team.dutyBatchTemplate ?: throw IllegalArgumentException("dutyBatch.template.required")
        val dutyBatchService = applicationContext.getBean(batchTemplate.batchServiceClass) as DutyBatchService
        return try {
            log.info("Batch duty upload: teamId={}, year={}, month={}, by={}", team.id, year, month, loginMember.id)
            dutyBatchService.batchUploadTeam(
                teamId = teamId,
                file = file,
                yearMonth = YearMonth.of(year, month)
            )
        } catch (e: DutyBatchException) {
            DutyBatchTeamResult.fail(e.errorCode, e.errorDetails)
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
        val member = memberService.findById(memberId)
        teamService.addMemberToTeam(teamId = teamId, memberId = memberId)
    }

    @DeleteMapping("/{teamId}/members")
    fun removeMember(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        val member = memberService.findById(memberId)
        teamService.removeMemberFromTeam(teamId, memberId)
    }

    @GetMapping("/members")
    fun members(
        @Login loginMember: LoginMember,
        @PageableDefault(page = 0, size = 10)
        @SortDefault(sort = ["name"], direction = Sort.Direction.ASC)
        page: Pageable,
        @RequestParam teamId: Long,
        @RequestParam(required = false, defaultValue = "") keyword: String,
    ): PageResponse<MemberInviteCandidateDto> {
        checkCanManage(login = loginMember, teamId = teamId)
        return PageResponse(memberService.searchMembersToInviteTeam(page = page, keyword = keyword))
    }

    @PostMapping("/{teamId}/manager")
    fun addManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanAdmin(login = loginMember, teamId = teamId)
        val member = memberService.findById(memberId)
        teamService.addTeamManager(teamId = teamId, memberId = memberId)
        log.info("Manager added to team: teamId={}, memberId={}, by={}", teamId, memberId, loginMember.id)
    }

    @DeleteMapping("/{teamId}/manager")
    fun removeManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanAdmin(login = loginMember, teamId = teamId)
        val member = memberService.findById(memberId)
        teamService.removeTeamManager(teamId = teamId, memberId = memberId)
        log.info("Manager removed from team: teamId={}, memberId={}, by={}", teamId, memberId, loginMember.id)
    }

    private fun checkCanManage(login: LoginMember, teamId: Long) {
        teamService.checkCanManage(login = login, teamId = teamId)
    }

    private fun checkCanAdmin(login: LoginMember, teamId: Long) {
        teamService.checkCanAdmin(login = login, teamId = teamId)
    }

}
