package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
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
        val dutyTypeSize = teamRepository.findById(TestData.team.id!!).orElseThrow().dutyTypes.size

        // When
        val dutyTypeCreateDto = DutyTypeCreateDto(TestData.team.id!!, "dutyType", "#f0f8ff")
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)

        // Then
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(created).isNotNull
        assertThat(team.dutyTypes).hasSize(dutyTypeSize + 1)
        assertThat(created.team).isEqualTo(team)
    }

    @Test
    fun `can't create same duty type name in same team`() {
        // Given
        val dutyTypeCreateDto = DutyTypeCreateDto(TestData.team.id!!, "dutyType", "#f0f8ff")
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)
        val dutyTypeCreateDto2 = DutyTypeCreateDto(TestData.team.id!!, "dutyType2", "#f0f8ff")
        val created2 = dutyTypeService.addDutyType(dutyTypeCreateDto2)

        assertThat(created).isNotNull
        assertThat(created2).isNotNull

        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.dutyTypes)
            .containsAll(
                listOf(created, created2)
            )

        // When
        assertThrows<IllegalArgumentException> {
            dutyTypeService.addDutyType(DutyTypeCreateDto(TestData.team.id!!, "dutyType", "#f0f8ff"))
        }
        assertThrows<IllegalArgumentException> {
            dutyTypeService.addDutyType(DutyTypeCreateDto(TestData.team.id!!, "dutyType2", "#f0f8ff"))
        }
    }

    @Test
    fun `update duty-type success`() {
        // Given
        val dutyTypeCreateDto = DutyTypeCreateDto(TestData.team.id!!, "dutyType", "#f0f8ff")
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)
        val dutyTypeSize = teamRepository.findById(TestData.team.id!!).orElseThrow().dutyTypes
        em.flush()

        // When
        val dutyTypeUpdateDto = DutyTypeUpdateDto(created.id!!, "changed", "#f0f8ff")
        dutyTypeService.update(dutyTypeUpdateDto)
        em.flush()
        em.clear()

        // Then
        val dutyType = dutyTypeRepository.findById(created.id!!).orElseThrow()

        assertThat(dutyType.id).isEqualTo(created.id)
        assertThat(
            teamRepository.findById(TestData.team.id!!).orElseThrow().dutyTypes
        ).hasSize(dutyTypeSize.size)
        assertThat(dutyType.name).isEqualTo(dutyTypeUpdateDto.name)
        assertThat(dutyType.color).isEqualTo(dutyTypeUpdateDto.color)
    }

    @Test
    fun `update duty type fails if same name already exist in the team`() {
        // Given
        val dutyTypeCreateDto = DutyTypeCreateDto(TestData.team.id!!, "dutyType", "#f0f8ff")
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)
        val dutyTypeCreateDto2 = DutyTypeCreateDto(TestData.team.id!!, "dutyType2", "#f0f8ff")
        val created2 = dutyTypeService.addDutyType(dutyTypeCreateDto2)
        em.flush()

        // Then
        val dutyTypeUpdateDto = DutyTypeUpdateDto(created.id!!, created2.name, "#f0f8ff")
        assertThrows<IllegalArgumentException> {
            dutyTypeService.update(dutyTypeUpdateDto)
        }
    }

    @Test
    fun `When DutyType is deleted, All related duties will be deleted`() {
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
        dutyTypeService.delete(dutyType.id!!)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType.id!!)).isEmpty
        assertThat(dutyRepository.findById(duty1.id!!)).isEmpty
        assertThat(dutyRepository.findById(duty2.id!!)).isEmpty
    }

    @Test
    fun `swap dutyType position`() {
        val dutyType1 = TestData.dutyTypes[0]
        val dutyType2 = TestData.dutyTypes[1]
        val position1 = dutyType1.position
        val position2 = dutyType2.position

        // When
        dutyTypeService.swapDutyTypePosition(dutyType1.id!!, dutyType2.id!!)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType1.id!!).get().position).isEqualTo(position2)
        assertThat(dutyTypeRepository.findById(dutyType2.id!!).get().position).isEqualTo(position1)
    }

}
