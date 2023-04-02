package com.tistory.shanepark.dutypark.department.service

import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentCreateDto
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DepartmentService(
    private val repository: DepartmentRepository
) {

    @Transactional(readOnly = true)
    fun findAll(pageable: Pageable): Page<DepartmentDto> {
        val findAll = repository.findAll(pageable)
        return findAll.map { DepartmentDto.of(it) }
    }

    @Transactional(readOnly = true)
    fun findById(id: Long): DepartmentDto {
        val findById = repository.findById(id).orElseThrow()
        return DepartmentDto.of(findById)
    }

    fun create(departmentCreateDto: DepartmentCreateDto): DepartmentDto {
        Department(departmentCreateDto.name).let {
            it.description = departmentCreateDto.description
            repository.save(it)
            return DepartmentDto.of(it)
        }
    }

    fun delete(id: Long) {
        val department = repository.findById(id).orElseThrow()
        if (department.members.isNotEmpty()) {
            throw IllegalStateException("Department has members")
        }
        if (department.dutyTypes.isNotEmpty()) {
            throw IllegalStateException("Department has dutyTypes")
        }
        repository.deleteById(id)
    }

    fun isDuplicated(name: String): Boolean {
        repository.findByName(name).let {
            return it != null
        }
    }

}
