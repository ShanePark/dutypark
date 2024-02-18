package com.tistory.shanepark.dutypark.department.controller

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult.*
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.department.service.DepartmentService
import com.tistory.shanepark.dutypark.duty.enums.Color
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
    val departmentRepository: DepartmentRepository,
    val memberRepository: MemberRepository,
) {

    @GetMapping
    fun findAll(@PageableDefault(page = 0, size = 10) page: Pageable): Page<SimpleDepartmentDto> {
        return departmentService.findAllWithMemberCount(page)
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
    ): ResponseEntity<Any> {
        departmentService.changeManager(departmentId = id, memberId = memberId)
        return ResponseEntity.ok().build()
    }

    @PatchMapping("/{id}/off-color")
    fun changeOffColor(
        @PathVariable id: Long,
        @RequestParam color: String
    ): ResponseEntity<Any> {
        val department = departmentRepository.findById(id).orElseThrow()
        department.offColor = Color.valueOf(color)
        departmentRepository.save(department)
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
