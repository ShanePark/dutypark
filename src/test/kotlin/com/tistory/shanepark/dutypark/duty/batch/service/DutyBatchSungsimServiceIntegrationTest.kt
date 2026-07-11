package com.tistory.shanepark.dutypark.duty.batch.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.batch.SungsimCakeParser
import com.tistory.shanepark.dutypark.duty.batch.domain.BatchParseResult
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.service.DutyPatternService
import com.tistory.shanepark.dutypark.duty.service.DutyResolver
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.context.bean.override.mockito.MockitoBean
import java.time.DayOfWeek.MONDAY
import java.time.YearMonth

class DutyBatchSungsimServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var dutyBatchService: DutyBatchSungsimService

    @Autowired
    lateinit var dutyPatternService: DutyPatternService

    @Autowired
    lateinit var dutyResolver: DutyResolver

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @MockitoBean
    lateinit var parser: SungsimCakeParser

    @Test
    fun `uploaded off day remains an explicit override when a weekly pattern would work`() {
        TestData.dutyTypes.drop(1).forEach { dutyType ->
            dutyType.hidden = true
            dutyTypeRepository.save(dutyType)
        }
        em.flush()
        em.clear()

        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        dutyPatternService.updateMine(
            member.id!!,
            DutyPatternUpdateDto(setOf(MONDAY), holidayOff = false),
        )

        val month = YearMonth.now().plusMonths(1)
        val offMonday = (1..month.lengthOfMonth())
            .map(month::atDay)
            .first { it.dayOfWeek == MONDAY }
        val parsed = BatchParseResult(
            startDate = month.atDay(1),
            endDate = month.atEndOfMonth(),
            offDayResult = mapOf(member.name to setOf(offMonday)),
        )
        whenever(parser.parseDayOff(eq(month), any())).thenReturn(parsed)

        dutyBatchService.batchUploadMember(
            file = MockMultipartFile(
                "file",
                "duty.xlsx",
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                ByteArray(0),
            ),
            memberId = member.id!!,
            yearMonth = month,
        )

        val persistedOff = dutyRepository.findByMemberAndDutyDate(member, offMonday)
        assertThat(persistedOff).isNotNull
        assertThat(persistedOff?.dutyType).isNull()
        val resolved = dutyResolver.resolve(member, offMonday)
        assertThat(resolved.source).isEqualTo(DutySource.OVERRIDE)
        assertThat(resolved.dutyType).isNull()
    }
}
