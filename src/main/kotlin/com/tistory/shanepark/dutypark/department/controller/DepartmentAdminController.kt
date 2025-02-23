package com.tistory.shanepark.dutypark.department.controller

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardDepartment
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult.*
import com.tistory.shanepark.dutypark.department.service.DepartmentService
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import jakarta.validation.Valid
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin/api/departments")
class DepartmentAdminController(
    val departmentService: DepartmentService,
    val memberRepository: MemberRepository,
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
