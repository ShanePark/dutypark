package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.DayOfWeek.MONDAY

class DutyTypeServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var dutyTypeService: DutyTypeService

    @Autowired
    private lateinit var dutyRepository: DutyRepository

    @Autowired
    private lateinit var dutyPatternService: DutyPatternService

    @Test
    fun `When DutyType is hidden, related duties are preserved`() {
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
        dutyTypeService.updateVisibility(dutyType.id!!, true)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType.id!!).orElseThrow().hidden).isTrue()
        assertThat(dutyRepository.findById(duty1.id!!)).isPresent
        assertThat(dutyRepository.findById(duty2.id!!)).isPresent
    }

    @Test
    fun `adding a second visible duty type terminates active patterns`() {
        leaveOnlyFirstDutyTypeVisible()
        dutyPatternService.updateMine(TestData.member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))

        dutyTypeService.addDutyType(
            DutyTypeCreateDto(TestData.team.id!!, "추가근무", "#123456")
        )

        assertThat(dutyPatternService.getMine(TestData.member.id!!).pattern).isNull()
    }

    @Test
    fun `hiding the sole visible duty type terminates active patterns`() {
        leaveOnlyFirstDutyTypeVisible()
        dutyPatternService.updateMine(TestData.member.id!!, DutyPatternUpdateDto(setOf(MONDAY), true))

        dutyTypeService.updateVisibility(TestData.dutyTypes.first().id!!, true)

        assertThat(dutyPatternService.getMine(TestData.member.id!!).pattern).isNull()
    }

    private fun leaveOnlyFirstDutyTypeVisible() {
        TestData.dutyTypes.drop(1).forEach {
            it.hidden = true
            dutyTypeRepository.save(it)
        }
        em.flush()
        em.clear()
    }

}
