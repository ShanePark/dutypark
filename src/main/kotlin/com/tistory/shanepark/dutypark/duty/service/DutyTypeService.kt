package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import jakarta.persistence.EntityManager
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DutyTypeService(
    private val repository: DutyTypeRepository,
    private val dutyRepository: DutyRepository,
    private val departmentRepository: DepartmentRepository,
    private val entityMapper: EntityManager,
) {

    fun delete(id: Long) {
        val dutyType = repository.findById(id).orElseThrow()
        delete(dutyType)
    }

    fun delete(dutyType: DutyType) {
        dutyRepository.setDutyTypeNullIfDutyTypeIs(dutyType)
        entityMapper.clear()
        repository.delete(dutyType)
    }

    fun addDutyType(dutyTypeCreateDto: DutyTypeCreateDto): DutyType {
        val department = departmentRepository.findById(dutyTypeCreateDto.departmentId).orElseThrow()
        return department.addDutyType(dutyTypeCreateDto.name, dutyTypeCreateDto.color)
    }

}
