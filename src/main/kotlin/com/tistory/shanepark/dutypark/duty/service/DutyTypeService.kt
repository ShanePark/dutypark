package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

@Service
@Transactional
class DutyTypeService(
    private val dutyTypeRepository: DutyTypeRepository,
    private val teamRepository: TeamRepository,
    private val dutyRepository: DutyRepository,
    private val clock: Clock,
) {

    fun findById(id: Long): DutyTypeDto {
        val dutyType = dutyTypeRepository.findById(id).orElseThrow()
        return DutyTypeDto(dutyType)
    }

    @Transactional(timeout = 20)
    fun updateVisibility(dutyTypeId: Long, hidden: Boolean): DutyType {
        val teamId = dutyTypeRepository.findTeamIdById(dutyTypeId) ?: throw NoSuchElementException()
        val team = teamRepository.findByIdForUpdate(teamId).orElseThrow()
        val dutyType = team.dutyTypes.firstOrNull { it.id == dutyTypeId } ?: throw NoSuchElementException()
        if (dutyType.hidden == hidden) return dutyType
        val beforeCount = team.dutyTypes.count { !it.hidden }
        dutyType.hidden = hidden
        cleanupAutomaticDutiesWhenAmbiguous(team.id, beforeCount, beforeCount + if (hidden) -1 else 1)
        return dutyType
    }

    @Transactional(timeout = 20)
    fun addDutyType(dutyTypeCreateDto: DutyTypeCreateDto): DutyType {
        val team = teamRepository.findByIdForUpdate(dutyTypeCreateDto.teamId).orElseThrow()
        if (team.dutyTypes.any { it.name == dutyTypeCreateDto.name }) {
            throw IllegalArgumentException("DutyType already exists")
        }
        val beforeCount = team.dutyTypes.count { !it.hidden }
        return team.addDutyType(dutyTypeCreateDto.name, dutyTypeCreateDto.color).also {
            cleanupAutomaticDutiesWhenAmbiguous(team.id, beforeCount, beforeCount + 1)
        }
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

    private fun cleanupAutomaticDutiesWhenAmbiguous(teamId: Long?, beforeCount: Int, afterCount: Int) {
        if (beforeCount == 1 && afterCount != 1) {
            dutyRepository.deleteAutomaticByTeamIdAndDutyDateGreaterThanEqual(
                requireNotNull(teamId),
                LocalDate.now(clock.withZone(SEOUL)),
            )
        }
    }

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
