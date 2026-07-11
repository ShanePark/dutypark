package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPIDataGoKr
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.whenever
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
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
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

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

    @Test
    fun `rolled back API load is evicted from memory and retried on the next lookup`() {
        val date = LocalDate.of(2042, 10, 3)
        val calendarView = CalendarView(2042, 10)
        whenever(holidayAPI.requestHolidays(2042)).thenReturn(
            listOf(HolidayDto("개천절", true, date))
        )

        assertThrows<IllegalStateException> {
            transactionalLookup.findThenRollback(calendarView)
        }
        assertThat(holidayRepository.findAllByLocalDateBetween(date, date)).isEmpty()

        transactionalLookup.find(calendarView)

        assertThat(holidayRepository.findAllByLocalDateBetween(date, date)).hasSize(1)
        verify(holidayAPI, times(2)).requestHolidays(2042)
    }

    @Test
    fun `concurrent first lookups with a single connection pool load and persist a year once`() {
        val date = LocalDate.of(2043, 5, 5)
        val calendarView = CalendarView(2043, 5)
        whenever(holidayAPI.requestHolidays(2043)).thenReturn(
            listOf(HolidayDto("어린이날", true, date))
        )
        val start = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(2)
        val futures = List(2) {
            executor.submit {
                start.await()
                transactionalLookup.find(calendarView)
            }
        }
        try {
            start.countDown()
            futures.forEach { it.get(5, TimeUnit.SECONDS) }
        } finally {
            futures.filterNot { it.isDone }.forEach { it.cancel(true) }
            executor.shutdownNow()
            executor.awaitTermination(5, TimeUnit.SECONDS)
        }

        assertThat(holidayRepository.findAllByLocalDateBetween(date, date)).hasSize(1)
        verify(holidayAPI).requestHolidays(2043)
    }

    open class TransactionalLookup(
        private val holidayService: HolidayService,
    ) {
        @Transactional
        open fun find(calendarView: CalendarView) = holidayService.findHolidays(calendarView)

        @Transactional
        open fun findThenRollback(calendarView: CalendarView) {
            holidayService.findHolidays(calendarView)
            throw IllegalStateException("force rollback")
        }
    }

    @TestConfiguration
    class Config {
        @Bean
        fun transactionalLookup(holidayService: HolidayService) = TransactionalLookup(holidayService)
    }
}
