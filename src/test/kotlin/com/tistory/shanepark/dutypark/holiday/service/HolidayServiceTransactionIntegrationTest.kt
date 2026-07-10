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
@TestPropertySource(properties = ["spring.datasource.url=jdbc:h2:mem:holiday-service-tx"])
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class HolidayServiceTransactionIntegrationTest {

    @Autowired
    lateinit var holidayService: HolidayService

    @Autowired
    lateinit var holidayRepository: HolidayRepository

    @Autowired
    lateinit var readOnlyLookup: ReadOnlyLookup

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
    fun `first holiday lookup persists API results outside the caller read-only transaction`() {
        val date = LocalDate.of(2041, 5, 5)
        whenever(holidayAPI.requestHolidays(2041)).thenReturn(
            listOf(HolidayDto("어린이날", true, date))
        )

        readOnlyLookup.find(CalendarView(2041, 5))

        val persisted = holidayRepository.findAllByLocalDateBetween(date, date)
        assertThat(persisted).hasSize(1)
        assertThat(persisted.single().dateName).isEqualTo("어린이날")
        assertThat(persisted.single().isHoliday).isTrue()
    }

    open class ReadOnlyLookup(
        private val holidayService: HolidayService,
    ) {
        @Transactional(readOnly = true)
        open fun find(calendarView: CalendarView) = holidayService.findHolidays(calendarView)
    }

    @TestConfiguration
    class Config {
        @Bean
        fun readOnlyLookup(holidayService: HolidayService) = ReadOnlyLookup(holidayService)
    }
}
