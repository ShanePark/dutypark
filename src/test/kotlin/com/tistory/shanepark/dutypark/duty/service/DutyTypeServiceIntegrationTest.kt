package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.DayOfWeek.MONDAY
import java.time.LocalDate

class DutyTypeServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var dutyTypeService: DutyTypeService

    @Autowired
    private lateinit var dutyRepository: DutyRepository

    @Autowired
    private lateinit var dutyPatternService: DutyPatternService

    @Autowired
    private lateinit var dutyResolver: DutyResolver

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
    fun `adding a second visible duty type keeps active patterns configurable`() {
        leaveOnlyFirstDutyTypeVisible()
        dutyPatternService.updateMine(TestData.member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))

        dutyTypeService.addDutyType(
            DutyTypeCreateDto(TestData.team.id!!, "추가근무", "#123456")
        )

        assertThat(dutyPatternService.getMine(TestData.member.id!!).pattern).isNotNull()
        assertThat(dutyPatternService.getMine(TestData.member.id!!).configurable).isTrue()
    }

    @Test
    fun `hiding and restoring the sole visible duty type pauses and resumes the pattern`() {
        leaveOnlyFirstDutyTypeVisible()
        dutyPatternService.updateMine(TestData.member.id!!, DutyPatternUpdateDto(setOf(MONDAY), false))
        val monday = generateSequence(LocalDate.now()) { it.plusDays(1) }.first { it.dayOfWeek == MONDAY }
        dutyTypeService.updateVisibility(TestData.dutyTypes.first().id!!, true)
        assertThat(dutyResolver.resolve(TestData.member, monday).source).isEqualTo(DutySource.PATTERN_PAUSED)
        assertThat(dutyPatternService.getMine(TestData.member.id!!).pattern).isNotNull()

        dutyTypeService.updateVisibility(TestData.dutyTypes.first().id!!, false)

        assertThat(dutyResolver.resolve(TestData.member, monday).source).isEqualTo(DutySource.PATTERN)
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
