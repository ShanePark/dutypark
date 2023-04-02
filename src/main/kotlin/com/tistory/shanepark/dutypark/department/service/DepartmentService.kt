package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service

@Service
class DepartmentService(
    private val departmentRepository: DepartmentRepository
) {

    fun findAll(pageable: Pageable): Page<DepartmentDto> {
        val findAll = departmentRepository.findAll(pageable)
        return findAll.map { DepartmentDto.of(it) }
    }

    fun findById(id: Long): DepartmentDto {
        val findById = departmentRepository.findById(id).orElseThrow()
        return DepartmentDto.of(findById)
    }

}
