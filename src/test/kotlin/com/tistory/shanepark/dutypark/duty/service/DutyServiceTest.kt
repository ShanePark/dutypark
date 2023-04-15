package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.*
import org.springframework.beans.factory.annotation.Autowired

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

        val dutyDto = dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]
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

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
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
        assertThat(dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]).isNull()
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

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
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

        dutyService.findDutyByMemberAndYearAndMonth(member, 2022, 10)[10]?.let {
            assert(it.dutyType == dutyTypes[0].name)
        }
    }

}
