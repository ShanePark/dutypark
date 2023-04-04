package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.TestData
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class DutyTypeServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var dutyTypeService: DutyTypeService

    @Autowired
    private lateinit var dutyTypeRepository: DutyTypeRepository

    @Autowired
    private lateinit var dutyRepository: DutyRepository

    @Test
    fun delete() {
        // Given
        val dutyType = TestData.dutyTypes[0]
        val member = TestData.member

        val duty1 = dutyRepository.save(
            Duty(
                dutyYear = 2022,
                dutyMonth = 10,
                dutyDay = 10,
                dutyType = dutyType,
                member = member
            )
        )
        val duty2 = dutyRepository.save(
            Duty(
                dutyYear = 2022,
                dutyMonth = 10,
                dutyDay = 11,
                dutyType = dutyType,
                member = member
            )
        )
        assertThat(dutyRepository.findById(duty1.id!!).get().dutyType).isNotNull
        assertThat(dutyRepository.findById(duty2.id!!).get().dutyType).isNotNull
        assertThat(dutyTypeRepository.findById(dutyType.id!!)).isNotNull

        // When
        dutyTypeService.delete(dutyType)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType.id!!)).isEmpty
        assertThat(dutyRepository.findById(duty1.id!!).get().dutyType).isNull()
        assertThat(dutyRepository.findById(duty2.id!!).get().dutyType).isNull()
    }

}
