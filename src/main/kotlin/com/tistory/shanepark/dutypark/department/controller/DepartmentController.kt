package com.tistory.shanepark.dutypark.department.controller

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.dto.SimpleDepartmentDto
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult
import com.tistory.shanepark.dutypark.department.domain.enums.DepartmentNameCheckResult.*
import com.tistory.shanepark.dutypark.department.service.DepartmentService
import jakarta.validation.Valid
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.web.PageableDefault
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin/api/departments")
class DepartmentController(
    val departmentService: DepartmentService
) {

    @GetMapping
    fun findAll(@PageableDefault(page = 0, size = 10) page: Pageable): Page<SimpleDepartmentDto> {
        return departmentService.findAllWithMemberCount(page)
    }

    @GetMapping("/{id}")
    fun findById(@PathVariable id: Long): DepartmentDto {
        return departmentService.findById(id)
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

}
