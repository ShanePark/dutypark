package com.tistory.shanepark.dutypark.team.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.dto.SimpleTeamDto
import com.tistory.shanepark.dutypark.team.domain.dto.TeamCreateDto
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.domain.enums.TeamNameCheckResult
import com.tistory.shanepark.dutypark.team.domain.enums.TeamNameCheckResult.*
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.team.service.TeamService
import jakarta.validation.Valid
import org.springframework.context.ApplicationContext
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

@RestController
@RequestMapping("/admin/api/teams")
class TeamAdminController(
    val teamService: TeamService,
    val memberRepository: MemberRepository,
    private val teamRepository: TeamRepository,
    private val applicationContext: ApplicationContext,
) {

    private val log = logger()

    @GetMapping
    fun findAll(@PageableDefault(page = 0, size = 10) page: Pageable): PageResponse<SimpleTeamDto> {
        val result = teamService.findAllWithMemberCount(page)
        return PageResponse(result)
    }

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): TeamDto {
        return teamService.findByIdWithMembersAndDutyTypes(id)
    }

    @PostMapping
    fun create(@RequestBody @Valid teamCreateDto: TeamCreateDto): TeamDto {
        return teamService.create(teamCreateDto)
    }

    @PostMapping("/check")
    fun nameCheck(@RequestBody payload: Map<String, String>): TeamNameCheckResult {
        val name = payload["name"] ?: ""
        if (name.length < 2)
            return TOO_SHORT
        if (name.length > 20)
            return TOO_LONG
        if (teamService.isDuplicated(name))
            return DUPLICATED
        return OK
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long) {
        teamService.delete(id)
    }

    @PutMapping("/{id}/manager")
    fun changeManager(
        @PathVariable id: Long,
        @RequestParam memberId: Long?
    ) {
        teamService.changeManager(teamId = id, memberId = memberId)
    }

    @PatchMapping("/{id}/batch-template")
    fun updateBatchTemplate(
        @PathVariable id: Long,
        @RequestParam(name = "templateName", required = false) dutyBatchTemplate: DutyBatchTemplate?
    ) {
        teamService.updateBatchTemplate(id, dutyBatchTemplate)
    }

    @PostMapping("/{id}/duty")
    fun uploadBatchTemplate(
        @Login loginMember: LoginMember,
        @PathVariable id: Long,
        @RequestParam(name = "file") file: MultipartFile,
        @RequestParam(name = "year") year: Int,
        @RequestParam(name = "month") month: Int
    ): DutyBatchTeamResult {
        if (!loginMember.isAdmin) {
            throw DutyparkAuthException("$loginMember is not admin")
        }
        val team = teamRepository.findById(id).orElseThrow()
        val batchTemplate = team.dutyBatchTemplate ?: throw IllegalArgumentException("templateName is required")
        val dutyBatchService = applicationContext.getBean(batchTemplate.batchServiceClass) as DutyBatchService
        return try {
            log.info("batch duty upload by $loginMember for team ${team.name}(${team.id}) year=$year, month=$month")
            dutyBatchService.batchUploadTeam(
                teamId = id,
                file = file,
                yearMonth = YearMonth.of(year, month)
            )
        } catch (e: DutyBatchException) {
            DutyBatchTeamResult.fail(e.message ?: "알 수 없는 원인으로 시간표 업로드 실패.")
        }
    }

    @PatchMapping("/{id}/default-duty")
    fun updateDefaultDuty(
        @PathVariable id: Long,
        @RequestParam color: String,
        @RequestParam name: String,
    ) {
        teamService.updateDefaultDuty(id, name, color)
    }

    @PostMapping("/{id}/members")
    fun addMember(
        @PathVariable id: Long,
        @RequestParam memberId: Long
    ) {
        teamService.addMemberToTeam(teamId = id, memberId = memberId)
    }

    @DeleteMapping("/{id}/members")
    fun removeMember(
        @PathVariable id: Long,
        @RequestParam memberId: Long
    ) {
        teamService.removeMemberFromTeam(id, memberId)
    }

}
