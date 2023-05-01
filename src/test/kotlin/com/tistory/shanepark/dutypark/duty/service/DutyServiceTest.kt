package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.*
import org.springframework.beans.factory.annotation.Autowired
import java.time.YearMonth

internal class DutyServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var dutyService: DutyService

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Test
    @DisplayName("create new duty")
    fun create() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = dutyTypes[0].id,
                memberId = member.id!!,
            )
        )

        val dutyDto = dutyService.getDutiesAsMap(member, 2022, 10)[10]
        assertThat(dutyDto).isNotNull
        dutyDto?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }

    }

    @Test
    @DisplayName("change original duty to new duty")
    fun update() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = dutyTypes[1].id,
                memberId = member.id!!,
            )
        )

        dutyService.getDutiesAsMap(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[1].name)
        }

    }

    @Test
    @DisplayName("delete original duty")
    fun delete() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        dutyService.update(
            DutyUpdateDto(
                year = 2022,
                month = 10,
                day = 10,
                dutyTypeId = null,
                memberId = member.id!!,
            )
        )
        assertThat(dutyService.getDutiesAsMap(member, 2022, 10)[10]).isNull()
    }

    @Test
    @DisplayName("wrong member Id")
    fun wrongMemberId() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        assertThrows<NoSuchElementException> {
            dutyService.update(
                DutyUpdateDto(
                    year = 2022,
                    month = 10,
                    day = 10,
                    dutyTypeId = null,
                    memberId = -1L,
                )
            )
        }

        dutyService.getDutiesAsMap(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

    @Test
    @DisplayName("wrong duty Type Id")
    fun wrongDutyTypeId() {
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        val duty = Duty(
            dutyYear = 2022,
            dutyMonth = 10,
            dutyDay = 10,
            dutyType = dutyTypes[0],
            member = member
        )
        dutyRepository.save(duty)

        assertThrows<NoSuchElementException> {
            dutyService.update(
                DutyUpdateDto(
                    year = 2022,
                    month = 10,
                    day = 10,
                    dutyTypeId = -1,
                    memberId = member.id!!,
                )
            )
        }

        dutyService.getDutiesAsMap(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

    @Test
    fun `test getDuties`() {
        // Given
        val member = TestData.member
        val dutyTypes = TestData.dutyTypes
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 3,
                dutyDay = 31,
                dutyType = dutyTypes[0],
                member = member
            )
        )
        dutyRepository.save(
            Duty(
                dutyYear = 2023,
                dutyMonth = 4,
                dutyDay = 10,
                dutyType = dutyTypes[0],
                member = member
            )
        )

        // When
        val duties = dutyService.getDuties(member.id!!, YearMonth.of(2023, 4))

        // Then
        assertThat(duties).hasSize(42)
        assertThat(duties[0].month).isEqualTo(3)
        assertThat(duties[0].day).isEqualTo(26)
        assertThat(duties[5].dutyType).isEqualTo(dutyTypes[0].name)
        assertThat(duties[6].day).isEqualTo(1)
        val dutyDto = duties[15]
        assertThat(dutyDto.day).isEqualTo(10)
        assertThat(dutyDto.dutyType).isEqualTo(dutyTypes[0].name)
        duties[41].let {
            assertThat(it.month).isEqualTo(5)
            assertThat(it.day).isEqualTo(6)
        }
    }

}
