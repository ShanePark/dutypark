package com.tistory.shanepark.dutypark.duty.service

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
    private val entityMapper: EntityManager,
) {

    fun delete(dutyType: DutyType) {
        dutyRepository.setDutyTypeNullIfDutyTypeIs(dutyType)
        entityMapper.clear()
        repository.delete(dutyType)
    }
}
