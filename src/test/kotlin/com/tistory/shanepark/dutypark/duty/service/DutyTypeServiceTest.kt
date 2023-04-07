package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired

class DutyTypeServiceTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var dutyTypeService: DutyTypeService

    @Autowired
    private lateinit var dutyRepository: DutyRepository

    @Test
    fun `Create duty Type success`() {
        // Given
        val dutyTypeSize = departmentRepository.findById(TestData.department.id!!).orElseThrow().dutyTypes.size

        // When
        val dutyTypeCreateDto = DutyTypeCreateDto(TestData.department.id!!, "dutyType", Color.BLUE)
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)

        // Then
        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        assertThat(created).isNotNull
        assertThat(department.dutyTypes).hasSize(dutyTypeSize + 1)
        assertThat(created.department).isEqualTo(department)
    }

    @Test
    fun `can't create same duty type name in same department`() {
        // Given
        val dutyTypeCreateDto = DutyTypeCreateDto(TestData.department.id!!, "dutyType", Color.BLUE)
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)
        val dutyTypeCreateDto2 = DutyTypeCreateDto(TestData.department.id!!, "dutyType2", Color.BLUE)
        val created2 = dutyTypeService.addDutyType(dutyTypeCreateDto2)

        assertThat(created).isNotNull
        assertThat(created2).isNotNull

        val department = departmentRepository.findById(TestData.department.id!!).orElseThrow()
        assertThat(department.dutyTypes)
            .containsAll(
                listOf(created, created2)
            )

        // When
        assertThrows<IllegalArgumentException> {
            val dutyTypeCreateDto = DutyTypeCreateDto(TestData.department.id!!, "dutyType", Color.BLUE)
            dutyTypeService.addDutyType(dutyTypeCreateDto)
        }
        assertThrows<IllegalArgumentException> {
            val dutyTypeCreateDto = DutyTypeCreateDto(TestData.department.id!!, "dutyType2", Color.BLUE)
            dutyTypeService.addDutyType(dutyTypeCreateDto)
        }
    }

    @Test
    fun `When Duty Type is deleted, All related duties have null department`() {
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
