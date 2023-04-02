package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service

@Service
class DepartmentService(
    private val departmentRepository: DepartmentRepository
) {

    fun findAll(pageable: Pageable): Page<DepartmentDto> {
        val findAll = departmentRepository.findAll(pageable)
        return findAll.map { entityToDto(it) }
    }

    fun findById(id: Long): DepartmentDto {
        val findById = departmentRepository.findById(id).orElseThrow()
        return entityToDto(findById)
    }

    private fun entityToDto(findById: Department): DepartmentDto {
        val dutyTypes = findById.dutyTypes
            .map { DutyTypeDto(it.id, it.name, it.position, it.color.toString()) }
        return DepartmentDto(id = findById.id!!, name = findById.name, dutyTypes = dutyTypes)
    }

}
