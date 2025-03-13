package com.tistory.shanepark.dutypark.department.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.PageResponse
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult.*
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.department.service.DepartmentService
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTeamResult
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.duty.batch.exceptions.DutyBatchException
import com.tistory.shanepark.dutypark.duty.batch.service.DutyBatchService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.validation.Valid
import org.springframework.context.ApplicationContext
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import java.time.YearMonth

@RestController
@RequestMapping("/admin/api/departments")
class DepartmentAdminController(
    val departmentService: DepartmentService,
    val memberRepository: MemberRepository,
    private val departmentRepository: DepartmentRepository,
    private val applicationContext: ApplicationContext,
) {

    private val log = logger()

    @GetMapping
    fun findAll(@PageableDefault(page = 0, size = 10) page: Pageable): PageResponse<SimpleDepartmentDto> {
        val result = departmentService.findAllWithMemberCount(page)
        return PageResponse(result)
    }

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): DepartmentDto {
        return departmentService.findByIdWithMembersAndDutyTypes(id)
    }

    @PostMapping
    fun create(@RequestBody @Valid departmentCreateDto: DepartmentCreateDto): DepartmentDto {
        return departmentService.create(departmentCreateDto)
    }

    @PostMapping("/check")
    fun nameCheck(@RequestBody payload: Map<String, String>): DepartmentNameCheckResult {
        val name = payload["name"] ?: ""
        if (name.length < 2)
            return TOO_SHORT
        if (name.length > 20)
            return TOO_LONG
        if (departmentService.isDuplicated(name))
            return DUPLICATED
        return OK
    }

    @DeleteMapping("/{id}")
    fun delete(@PathVariable id: Long) {
        departmentService.delete(id)
    }

    @PutMapping("/{id}/manager")
    fun changeManager(
        @PathVariable id: Long,
        @RequestParam memberId: Long?
    ) {
        departmentService.changeManager(departmentId = id, memberId = memberId)
    }

    @PatchMapping("/{id}/batch-template")
    fun updateBatchTemplate(
        @PathVariable id: Long,
        @RequestParam(name = "templateName", required = false) dutyBatchTemplate: DutyBatchTemplate?
    ) {
        departmentService.updateBatchTemplate(id, dutyBatchTemplate)
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
        val department = departmentRepository.findById(id).orElseThrow()
        val batchTemplate = department.dutyBatchTemplate ?: throw IllegalArgumentException("templateName is required")
        val dutyBatchService = applicationContext.getBean(batchTemplate.batchServiceClass) as DutyBatchService
        return try {
            log.info("batch duty upload by $loginMember for department ${department.name}(${department.id}) year=$year, month=$month")
            dutyBatchService.batchUploadDepartment(
                departmentId = id,
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
        departmentService.updateDefaultDuty(id, name, color)
    }

    @PostMapping("/{id}/members")
    fun addMember(
        @PathVariable id: Long,
        @RequestParam memberId: Long
    ) {
        departmentService.addMemberToDepartment(departmentId = id, memberId = memberId)
    }

    @DeleteMapping("/{id}/members")
    fun removeMember(
        @PathVariable id: Long,
        @RequestParam memberId: Long
    ) {
        departmentService.removeMemberFromDepartment(id, memberId)
    }

}
