package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
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
    private val dutyPatternService: DutyPatternService,
) {

    fun findById(id: Long): DutyTypeDto {
        val dutyType = dutyTypeRepository.findById(id).orElseThrow()
        return DutyTypeDto(dutyType)
    }

    fun updateVisibility(dutyTypeId: Long, hidden: Boolean): DutyType {
        val dutyType = dutyTypeRepository.findById(dutyTypeId).orElseThrow()
        dutyType.hidden = hidden
        terminatePatternsIfTypeCountIsNotSingle(dutyType.team)
        return dutyType
    }

    fun addDutyType(dutyTypeCreateDto: DutyTypeCreateDto): DutyType {
        val team = teamRepository.findByIdWithDutyTypes(dutyTypeCreateDto.teamId).orElseThrow()
        val dutyType = team.addDutyType(dutyTypeCreateDto.name, dutyTypeCreateDto.color)
        terminatePatternsIfTypeCountIsNotSingle(team)
        return dutyType
    }

    fun update(dutyTypeUpdateDto: DutyTypeUpdateDto): DutyType {
        val dutyType = dutyTypeRepository.findById(dutyTypeUpdateDto.id).orElseThrow()
        val teamId = dutyType.team.id ?: throw IllegalArgumentException("DutyType has no team")
        val team = teamRepository.findByIdWithDutyTypes(teamId).orElseThrow()

        team.dutyTypes
            .filter { it.id != dutyType.id }
            .forEach {
                if (it.name == dutyTypeUpdateDto.name) {
                    throw IllegalArgumentException("dutyType.name.duplicate")
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

    private fun terminatePatternsIfTypeCountIsNotSingle(team: com.tistory.shanepark.dutypark.team.domain.entity.Team) {
        if (team.dutyTypes.count { !it.hidden } != 1) {
            dutyPatternService.terminateActivePatternsForTeam(team)
        }
    }

}
