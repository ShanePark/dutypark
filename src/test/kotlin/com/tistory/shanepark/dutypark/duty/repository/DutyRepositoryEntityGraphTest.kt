package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDate

class DutyRepositoryEntityGraphTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var dutyRepository: DutyRepository

    @Test
    fun `findByMemberAndDutyDate loads dutyType`() {
        // Given
        val dutyTypeId = requireNotNull(TestData.dutyTypes.first().id)
        val memberId = requireNotNull(TestData.member.id)
        val dutyType = dutyTypeRepository.getReferenceById(dutyTypeId)
        val member = memberRepository.getReferenceById(memberId)
        val dutyDate = LocalDate.of(2024, 1, 1)

        dutyRepository.save(Duty(dutyDate, dutyType, member))
        em.flush()
        em.clear()

        // When
        val found = dutyRepository.findByMemberAndDutyDate(member, dutyDate)

        // Then
        assertThat(found).isNotNull
        val duty = requireNotNull(found)
        assertThat(isDutyTypeLoaded(duty)).isTrue()
    }

    @Test
    fun `findByDutyDateAndMemberIn loads dutyType for each duty`() {
        // Given
        val dutyTypeId = requireNotNull(TestData.dutyTypes.first().id)
        val dutyType = dutyTypeRepository.getReferenceById(dutyTypeId)
        val member = memberRepository.getReferenceById(requireNotNull(TestData.member.id))
        val member2 = memberRepository.getReferenceById(requireNotNull(TestData.member2.id))
        val dutyDate = LocalDate.of(2024, 1, 2)

        dutyRepository.save(Duty(dutyDate, dutyType, member))
        dutyRepository.save(Duty(dutyDate, dutyType, member2))
        em.flush()
        em.clear()

        // When
        val duties = dutyRepository.findByDutyDateAndMemberIn(dutyDate, listOf(member, member2))

        // Then
        assertThat(duties).hasSize(2)
        assertThat(duties.all { isDutyTypeLoaded(it) }).isTrue()
    }

    private fun isDutyTypeLoaded(duty: Duty): Boolean {
        return em.entityManagerFactory.persistenceUnitUtil.isLoaded(duty, "dutyType")
    }
}
