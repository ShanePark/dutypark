package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPIDataGoKr
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.test.annotation.DirtiesContext
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.context.TestPropertySource
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate

@SpringBootTest
@Import(HolidayServiceTransactionIntegrationTest.Config::class)
@TestPropertySource(
    properties = [
        "spring.datasource.url=jdbc:h2:mem:holiday-service-tx",
        "spring.datasource.hikari.maximum-pool-size=1",
        "spring.datasource.hikari.connection-timeout=1000",
    ]
)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class HolidayServiceTransactionIntegrationTest {

    @Autowired
    lateinit var holidayService: HolidayService

    @Autowired
    lateinit var holidayRepository: HolidayRepository

    @Autowired
    lateinit var transactionalLookup: TransactionalLookup

    @MockitoBean
    lateinit var holidayAPI: HolidayAPIDataGoKr

    @BeforeEach
    fun clearBefore() {
        holidayService.resetHolidayInfo()
    }

    @AfterEach
    fun clearAfter() {
        holidayService.resetHolidayInfo()
    }

    @Test
    fun `first holiday lookup persists API results with a single connection pool`() {
        val date = LocalDate.of(2041, 5, 5)
        whenever(holidayAPI.requestHolidays(2041)).thenReturn(
            listOf(HolidayDto("어린이날", true, date))
        )

        transactionalLookup.find(CalendarView(2041, 5))

        val persisted = holidayRepository.findAllByLocalDateBetween(date, date)
        assertThat(persisted).hasSize(1)
        assertThat(persisted.single().dateName).isEqualTo("어린이날")
        assertThat(persisted.single().isHoliday).isTrue()
    }

    open class TransactionalLookup(
        private val holidayService: HolidayService,
    ) {
        @Transactional
        open fun find(calendarView: CalendarView) = holidayService.findHolidays(calendarView)
    }

    @TestConfiguration
    class Config {
        @Bean
        fun transactionalLookup(holidayService: HolidayService) = TransactionalLookup(holidayService)
    }
}
