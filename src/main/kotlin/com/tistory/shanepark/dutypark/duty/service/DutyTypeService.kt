package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.department.repository.DepartmentRepository
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import jakarta.persistence.EntityManager
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DutyTypeService(
    private val dutyTypeRepository: DutyTypeRepository,
    private val dutyRepository: DutyRepository,
    private val departmentRepository: DepartmentRepository,
    private val entityMapper: EntityManager,
) {

    fun delete(id: Long) {
        val dutyType = dutyTypeRepository.findById(id).orElseThrow()
        delete(dutyType)
    }

    fun delete(dutyType: DutyType) {
        dutyRepository.setDutyTypeNullIfDutyTypeIs(dutyType)
        entityMapper.clear()
        dutyTypeRepository.delete(dutyType)
    }

    fun addDutyType(dutyTypeCreateDto: DutyTypeCreateDto): DutyType {
        val department = departmentRepository.findByIdWithDutyTypes(dutyTypeCreateDto.departmentId).orElseThrow()
        return department.addDutyType(dutyTypeCreateDto.name, dutyTypeCreateDto.color)
    }

    fun update(dutyTypeUpdateDto: DutyTypeUpdateDto): DutyType {
        val dutyType = dutyTypeRepository.findById(dutyTypeUpdateDto.id).orElseThrow()
        val department = departmentRepository.findByIdWithDutyTypes(dutyType.department.id!!).orElseThrow()

        department.dutyTypes
            .filter { it.id != dutyType.id }
            .forEach {
                if (it.name == dutyTypeUpdateDto.name) {
                    throw IllegalArgumentException("중복된 근무명이 존재합니다.")
                }
            }

        dutyType.name = dutyTypeUpdateDto.name
        dutyType.color = dutyTypeUpdateDto.color
        return dutyType
    }

    fun swapDutyTypePosition(dutyTypeId1: Long, dutyTypeId2: Long) {
        if (dutyTypeId1 == dutyTypeId2)
            throw IllegalArgumentException("Same duty types can't be swapped")

        val dutyType1 = dutyTypeRepository.findById(dutyTypeId1).orElseThrow()
        val dutyType2 = dutyTypeRepository.findById(dutyTypeId2).orElseThrow()

        dutyType1.position = dutyType2.position.also { dutyType2.position = dutyType1.position }
    }

}
