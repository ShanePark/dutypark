package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.domain.dto.MemberInviteCandidateDto
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
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
        teamService.changeTeamAdmin(teamId = teamId, memberId = memberId, actor = loginMember)
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
        val batchTemplate = team.dutyBatchTemplate ?: throw IllegalArgumentException("dutyBatch.template.required")
        val dutyBatchService = applicationContext.getBean(batchTemplate.batchServiceClass)
        val yearMonth = YearMonth.of(year, month)
        val target = mapOf("type" to "Team", "teamId" to team.id, "teamName" to team.name)
        val uploadDetails = mapOf(
            "template" to batchTemplate.name,
            "year" to year,
            "month" to month,
            "fileName" to file.safeAuditFilename(),
            "fileSizeBytes" to file.size,
        )
        return try {
            val result = dutyBatchService.batchUploadTeam(
                teamId = teamId,
                file = file,
                yearMonth = yearMonth,
            )
            val successfulMembers = result.dutyBatchResult.count { it.second.result }
            val failedMembers = result.dutyBatchResult.size - successfulMembers
            val memberFailures = result.dutyBatchResult
                .filterNot { it.second.result }
                .map { (memberName, memberResult) ->
                    mapOf("memberName" to memberName, "errorCode" to memberResult.errorCode)
                }
            val details = uploadDetails + mapOf(
                "startDate" to result.startDate,
                "endDate" to result.endDate,
                "successfulMembers" to successfulMembers,
                "failedMembers" to failedMembers,
                "memberFailures" to memberFailures,
                "errorCode" to result.errorCode,
                "errorDetails" to result.errorDetails,
            )
            if (result.result) {
                log.auditEventAfterCommit(
                    event = "duty_batch.team_uploaded",
                    actor = loginMember.toAuditActor(),
                    target = target,
                    details = details,
                )
            } else {
                log.warn(
                    "Team duty batch upload failed {}",
                    auditContext(
                        mapOf(
                            "event" to "duty_batch.team_upload_failed",
                            "actor" to loginMember.toAuditActor(),
                            "target" to target,
                            "details" to details,
                        )
                    ),
                )
            }
            result
        } catch (e: DutyBatchException) {
            log.warn(
                "Team duty batch upload failed {}",
                auditContext(
                    mapOf(
                        "event" to "duty_batch.team_upload_failed",
                        "actor" to loginMember.toAuditActor(),
                        "target" to target,
                        "details" to uploadDetails + mapOf(
                            "errorCode" to e.errorCode,
                            "errorDetails" to e.errorDetails,
                        ),
                    )
                ),
            )
            DutyBatchTeamResult.fail(e.errorCode, e.errorDetails)
        }
    }

    @PatchMapping("/{teamId}/default-duty")
    fun updateDefaultDuty(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam color: String,
        @RequestParam name: String,
        @RequestParam(required = false) abbreviation: String? = null,
    ) {
        checkCanManage(login = loginMember, teamId = teamId)
        teamService.updateDefaultDuty(teamId, name, color, abbreviation)
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
        @Login loginMember: LoginMember,
        @PageableDefault(page = 0, size = 10)
        @SortDefault(sort = ["name"], direction = Sort.Direction.ASC)
        page: Pageable,
        @RequestParam teamId: Long,
        @RequestParam(required = false, defaultValue = "") keyword: String,
    ): PageResponse<MemberInviteCandidateDto> {
        checkCanManage(login = loginMember, teamId = teamId)
        return PageResponse(
            memberService.searchMembersToInviteTeam(page = page, keyword = keyword, loginMemberId = loginMember.id)
        )
    }

    @PostMapping("/{teamId}/manager")
    fun addManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanAdmin(login = loginMember, teamId = teamId)
        teamService.addTeamManager(teamId = teamId, memberId = memberId, actor = loginMember)
    }

    @DeleteMapping("/{teamId}/manager")
    fun removeManager(
        @Login loginMember: LoginMember,
        @PathVariable teamId: Long,
        @RequestParam memberId: Long
    ) {
        checkCanAdmin(login = loginMember, teamId = teamId)
        teamService.removeTeamManager(teamId = teamId, memberId = memberId, actor = loginMember)
    }

    private fun checkCanManage(login: LoginMember, teamId: Long) {
        teamService.checkCanManage(login = login, teamId = teamId)
    }

    private fun checkCanAdmin(login: LoginMember, teamId: Long) {
        teamService.checkCanAdmin(login = login, teamId = teamId)
    }

}

private fun MultipartFile.safeAuditFilename(): String? = originalFilename
    ?.substringAfterLast('/')
    ?.substringAfterLast('\\')
    ?.takeLast(120)
