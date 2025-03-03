package com.tistory.shanepark.dutypark.department.controller

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardDepartment
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
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import jakarta.validation.Valid
import org.springframework.context.ApplicationContext
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.http.ResponseEntity
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

    @GetMapping
    fun findAll(@PageableDefault(page = 0, size = 10) page: Pageable): Page<SimpleDepartmentDto> {
        return departmentService.findAllWithMemberCount(page)
    }

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): DashboardDepartment {
        val info = departmentService.findByIdWithMembersAndDutyTypes(id)
        val dashboard = departmentService.dashboardDepartment(id)
        return DashboardDepartment(
            department = info,
            groups = dashboard.groups
        )
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
    ): ResponseEntity<Any> {
        departmentService.changeManager(departmentId = id, memberId = memberId)
        return ResponseEntity.ok().build()
    }

    @PatchMapping("/{id}/batch-template")
    fun updateBatchTemplate(
        @PathVariable id: Long,
        @RequestParam(name = "templateName", required = false) dutyBatchTemplate: DutyBatchTemplate?
    ): ResponseEntity<Any> {
        departmentService.updateBatchTemplate(id, dutyBatchTemplate)
        return ResponseEntity.ok().build()
    }

    @PostMapping("/{id}/duty")
    fun uploadBatchTemplate(
        @PathVariable id: Long,
        @RequestParam(name = "file") file: MultipartFile,
        @RequestParam(name = "year") year: Int,
        @RequestParam(name = "month") month: Int
    ): DutyBatchTeamResult {
        val department = departmentRepository.findById(id).orElseThrow()
        val batchTemplate = department.dutyBatchTemplate ?: throw IllegalArgumentException("templateName is required")
        val dutyBatchService = applicationContext.getBean(batchTemplate.batchServiceClass) as DutyBatchService
        try {
            return dutyBatchService.batchUploadDepartment(
                departmentId = id,
                file = file,
                yearMonth = YearMonth.of(year, month)
            )
        } catch (e: DutyBatchException) {
            return DutyBatchTeamResult.fail(e.message ?: "알 수 없는 원인으로 시간표 업로드 실패.")
        }
    }

    @PatchMapping("/{id}/default-duty")
    fun updateDefaultDuty(
        @PathVariable id: Long,
        @RequestParam color: String,
        @RequestParam name: String,
    ): ResponseEntity<Any> {
        departmentService.updateDefaultDuty(id, name, color)
        return ResponseEntity.ok().build()
    }

    @PostMapping("/{id}/members")
    fun addMember(
        @PathVariable id: Long,
        @RequestParam memberId: Long
    ): ResponseEntity<Any> {
        departmentService.addMemberToDepartment(departmentId = id, memberId = memberId)
        return ResponseEntity.ok().build()
    }

    @DeleteMapping("/{id}/members")
    fun removeMember(
        @PathVariable id: Long,
        @RequestParam memberId: Long
    ): ResponseEntity<Any> {
        departmentService.removeMemberFromDepartment(id, memberId)
        return ResponseEntity.ok().build()
    }

}
