package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class DutyTypeService(
    private val dutyTypeRepository: DutyTypeRepository,
    private val teamRepository: TeamRepository,
) {

    fun delete(dutyTypeId: Long) {
        val dutyType = dutyTypeRepository.findById(dutyTypeId).orElseThrow()
        dutyTypeRepository.delete(dutyType)
    }

    fun addDutyType(dutyTypeCreateDto: DutyTypeCreateDto): DutyType {
        val team = teamRepository.findByIdWithDutyTypes(dutyTypeCreateDto.teamId).orElseThrow()
        return team.addDutyType(dutyTypeCreateDto.name, dutyTypeCreateDto.color)
    }

    fun update(dutyTypeUpdateDto: DutyTypeUpdateDto): DutyType {
        val dutyType = dutyTypeRepository.findById(dutyTypeUpdateDto.id).orElseThrow()
        val team = teamRepository.findByIdWithDutyTypes(dutyType.team.id!!).orElseThrow()

        team.dutyTypes
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
