package com.tistory.shanepark.dutypark.holiday.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.time.AdjustableTestClock
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPI
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.never
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.slf4j.LoggerFactory
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

@ExtendWith(MockitoExtension::class)
class HolidayServiceTest {

    lateinit var holidayService: HolidayService

    @Mock
    lateinit var holidayAPI: HolidayAPI

    @Mock
    lateinit var holidayRepository: HolidayRepository

    @Mock
    lateinit var dutyRepository: DutyRepository

    @Mock
    lateinit var holidaySlackNotifier: HolidaySlackNotifier

    private val clock = Clock.fixed(Instant.parse("2026-07-10T16:00:00Z"), ZoneOffset.UTC)

    @BeforeEach
    fun setUp() {
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, clock, holidaySlackNotifier)
    }

    @Test
    fun `reset clears future automatic duties from the Seoul current date`() {
        holidayService.resetHolidayInfo()

        verify(dutyRepository).deleteAutomaticByDutyDateGreaterThanEqual(LocalDate.of(2026, 7, 11))
        verify(holidayRepository).deleteAll()
    }

    @Test
    fun `reset emits an audit event when holiday and cache snapshots are empty`() {
        val logger = LoggerFactory.getLogger(HolidayService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)

        try {
            holidayService.resetHolidayInfo(AuditActor(id = 9L, name = "Holiday Admin"))
        } finally {
            logger.detachAppender(appender)
        }

        verify(dutyRepository).deleteAutomaticByDutyDateGreaterThanEqual(LocalDate.of(2026, 7, 11))
        verify(holidayRepository).deleteAll()
        verify(holidayRepository, never()).count()
        assertThat(appender.list).hasSize(1)
        assertThat(appender.list.single().formattedMessage)
            .contains("\"event\":\"holiday_information_reset\"", "\"name\":\"Holiday Admin\"")
            .doesNotContain("holidayRecordCountBefore", "holidayRecordCountAfter")
            .contains("\"cachedHolidayYearsBefore\":[]", "\"cachedHolidayYearsAfter\":[]")
    }

    @Test
    fun `findHolidaysTest-loadFromMemory`() {
        val calendarView = CalendarView(2023, 5)
        HolidayService::class.java.getDeclaredField("holidayMap").apply {
            isAccessible = true
            set(holidayService, mutableMapOf(2023 to holiday2023Dto()))
        }

        val result = holidayService.findHolidays(calendarView)

        assert2023MayResult(result)
    }

    @Test
    fun `findHolidaysTest-loadFromDB`() {
        val calendarView = CalendarView(2023, 5)

        `when`(holidayRepository.findAllByLocalDateBetween(any(), any()))
            .thenReturn(holiday2023Entity())
        val result = holidayService.findHolidays(calendarView)

        assert2023MayResult(result)
    }

    @Test
    fun `findHolidaysTest-loadFromAPI`() {
        val calendarView = CalendarView(2023, 5)

        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(any())).thenReturn(holiday2023Dto())
        val result = holidayService.findHolidays(calendarView)

        assert2023MayResult(result)
        verify(holidayRepository).saveAll(any<List<Holiday>>())
    }

    @Test
    fun `test december 2023`() {
        val calendarView = CalendarView(2023, 12)

        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2023)).thenReturn(holiday2023Dto())
        `when`(holidayAPI.requestHolidays(2024)).thenReturn(holiday2024Dto())
        val result = holidayService.findHolidays(calendarView)

        assert2023DecemberResult(result)
    }

    @Test
    fun `years outside 2000 through three years after the Seoul current year return empty without loading`() {
        for (calendarView in listOf(CalendarView(1999, 6), CalendarView(2030, 6), CalendarView(1, 1), CalendarView(9999, 6))) {
            val result = holidayService.findHolidays(calendarView)

            assertThat(result).hasSize(42).allSatisfy { assertThat(it).isEmpty() }
        }

        verifyNoInteractions(holidayAPI, holidayRepository)
        assertThat(perYearState("holidayMap")).isEmpty()
        assertThat(perYearState("locks")).isEmpty()
        assertThat(perYearState("emptyYearCheckedAt")).isEmpty()
    }

    @Test
    fun `boundary years 2000 and three years after the Seoul current year still load from the API`() {
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2000)).thenReturn(listOf(HolidayDto("현충일", true, LocalDate.of(2000, 6, 6))))
        `when`(holidayAPI.requestHolidays(2029)).thenReturn(listOf(HolidayDto("현충일", true, LocalDate.of(2029, 6, 6))))

        holidayService.findHolidays(CalendarView(2000, 6))
        holidayService.findHolidays(CalendarView(2029, 6))

        verify(holidayAPI).requestHolidays(2000)
        verify(holidayAPI).requestHolidays(2029)
        assertThat(perYearState("holidayMap")).containsOnlyKeys(2000, 2029)
    }

    @Test
    fun `calendar padding outside the allowed years is not loaded`() {
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())

        holidayService.findHolidays(CalendarView(2000, 1))
        holidayService.findHolidays(CalendarView(2029, 12))

        verify(holidayAPI).requestHolidays(2000)
        verify(holidayAPI).requestHolidays(2029)
        verify(holidayAPI, never()).requestHolidays(1999)
        verify(holidayAPI, never()).requestHolidays(2030)
        assertThat(perYearState("locks")).containsOnlyKeys(2000, 2029)
        assertThat(perYearState("emptyYearCheckedAt")).containsOnlyKeys(2000, 2029)
    }

    @Test
    fun `allowed year range follows the Seoul current date`() {
        val newYearInSeoul = Clock.fixed(Instant.parse("2026-12-31T16:00:00Z"), ZoneOffset.UTC)
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, newYearInSeoul, holidaySlackNotifier)
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())

        holidayService.findHolidays(CalendarView(2030, 6))
        holidayService.findHolidays(CalendarView(2031, 6))

        verify(holidayAPI).requestHolidays(2030)
        verify(holidayAPI, never()).requestHolidays(2031)
    }

    @Test
    fun `an empty year is not requested again within 24 hours`() {
        val clock = adjustableClock()
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, clock, holidaySlackNotifier)
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2029)).thenReturn(listOf())

        holidayService.findHolidays(CalendarView(2029, 6))
        clock.advance(Duration.ofHours(24).minusSeconds(1))
        val result = holidayService.findHolidays(CalendarView(2029, 6))

        assertThat(result).hasSize(42).allSatisfy { assertThat(it).isEmpty() }
        verify(holidayAPI, times(1)).requestHolidays(2029)
        verify(holidayRepository, times(1)).findAllByLocalDateBetween(any(), any())
    }

    @Test
    fun `an empty year is requested again after 24 hours and newly announced holidays are cached`() {
        val clock = adjustableClock()
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, clock, holidaySlackNotifier)
        val announced = HolidayDto("현충일", true, LocalDate.of(2029, 6, 6))
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2029)).thenReturn(listOf(), listOf(announced))

        holidayService.findHolidays(CalendarView(2029, 6))
        clock.advance(Duration.ofHours(24))
        val result = holidayService.findHolidays(CalendarView(2029, 6))

        assertThat(result.flatMap { it }).containsExactly(announced)
        verify(holidayAPI, times(2)).requestHolidays(2029)
        assertThat(perYearState("holidayMap")).containsOnlyKeys(2029)
        assertThat(perYearState("emptyYearCheckedAt")).isEmpty()
    }

    @Test
    fun `a failed fetch is treated as an empty year for 24 hours`() {
        val clock = adjustableClock()
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, clock, holidaySlackNotifier)
        val announced = HolidayDto("현충일", true, LocalDate.of(2029, 6, 6))
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2029))
            .thenThrow(IllegalStateException("upstream failure"))
            .thenReturn(listOf(announced))

        val failed = holidayService.findHolidays(CalendarView(2029, 6))
        clock.advance(Duration.ofHours(24).minusSeconds(1))
        val withinWindow = holidayService.findHolidays(CalendarView(2029, 6))
        verify(holidayAPI, times(1)).requestHolidays(2029)

        clock.advance(Duration.ofSeconds(1))
        val afterWindow = holidayService.findHolidays(CalendarView(2029, 6))

        assertThat(failed).hasSize(42).allSatisfy { assertThat(it).isEmpty() }
        assertThat(withinWindow).hasSize(42).allSatisfy { assertThat(it).isEmpty() }
        assertThat(afterWindow.flatMap { it }).containsExactly(announced)
        verify(holidayAPI, times(2)).requestHolidays(2029)
    }

    @Test
    fun `a failed fetch sends one Slack alert per retry window`() {
        val clock = adjustableClock()
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, clock, holidaySlackNotifier)
        val failure = IllegalStateException("upstream failure")
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2029)).thenThrow(failure)

        holidayService.findHolidays(CalendarView(2029, 6))
        clock.advance(Duration.ofHours(24).minusSeconds(1))
        holidayService.findHolidays(CalendarView(2029, 6))
        verify(holidaySlackNotifier, times(1)).fetchFailed(2029, failure)

        clock.advance(Duration.ofSeconds(1))
        holidayService.findHolidays(CalendarView(2029, 6))

        verify(holidaySlackNotifier, times(2)).fetchFailed(2029, failure)
    }

    @Test
    fun `an empty fetch sends no Slack alert`() {
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2029)).thenReturn(listOf())

        holidayService.findHolidays(CalendarView(2029, 6))

        verify(holidayAPI).requestHolidays(2029)
        verifyNoInteractions(holidaySlackNotifier)
    }

    @Test
    fun `a year with holidays stays cached beyond 24 hours`() {
        val clock = adjustableClock()
        holidayService = HolidayService(holidayRepository, holidayAPI, dutyRepository, clock, holidaySlackNotifier)
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2023)).thenReturn(holiday2023Dto())

        holidayService.findHolidays(CalendarView(2023, 5))
        clock.advance(Duration.ofDays(2))
        val result = holidayService.findHolidays(CalendarView(2023, 5))

        assert2023MayResult(result)
        verify(holidayAPI, times(1)).requestHolidays(2023)
        verify(holidayRepository, times(1)).findAllByLocalDateBetween(any(), any())
    }

    @Test
    fun `reset forgets remembered empty years`() {
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())

        holidayService.findHolidays(CalendarView(2029, 6))
        holidayService.resetHolidayInfo()
        holidayService.findHolidays(CalendarView(2029, 6))

        verify(holidayAPI, times(2)).requestHolidays(2029)
    }

    private fun adjustableClock() = AdjustableTestClock().apply {
        setDate(LocalDate.of(2026, 7, 11), ZoneId.of("Asia/Seoul"))
    }

    @Suppress("UNCHECKED_CAST")
    private fun perYearState(fieldName: String): Map<Int, Any> =
        HolidayService::class.java.getDeclaredField(fieldName).apply { isAccessible = true }
            .get(holidayService) as Map<Int, Any>

    private fun assert2023MayResult(result: Array<List<HolidayDto>>) {
        assertThat(result.size).isEqualTo(42)
        assertThat(result[0]).isEmpty()
        assertThat(result[1]).isEmpty()
        assertThat(result[2]).isEmpty()
        assertThat(result[3]).isEmpty()
        assertThat(result[4]).isEmpty()
        assertThat(result[5]).hasSize(1)
        val childrenDay = result[5][0]
        childrenDay.let {
            assertThat(it.dateName).isEqualTo("어린이날")
            assertThat(it.localDate).isEqualTo(LocalDate.of(2023, 5, 5))
            assertThat(it.isHoliday).isTrue
        }
        assertThat(result[27]).hasSize(1)
        val buddhaBirthday = result[27][0]
        buddhaBirthday.let {
            assertThat(it.localDate).isEqualTo(LocalDate.of(2023, 5, 27))
            assertThat(it.isHoliday).isTrue
        }
        assertThat(result[29]).hasSize(1)
        val substituteHoliday = result[29][0]
        substituteHoliday.let {
            assertThat(it.dateName).isEqualTo("대체공휴일")
            assertThat(it.localDate).isEqualTo(LocalDate.of(2023, 5, 29))
            assertThat(it.isHoliday).isTrue
        }
    }

    private fun assert2023DecemberResult(result: Array<List<HolidayDto>>) {
        assertThat(result.size).isEqualTo(42)
        val newYear = result[36][0]
        newYear.let {
            assertThat(it.dateName).isEqualTo("신정")
            assertThat(it.localDate).isEqualTo(LocalDate.of(2024, 1, 1))
            assertThat(it.isHoliday).isTrue
        }
    }

    companion object {
        fun holiday2023Dto(): List<HolidayDto> {
            return listOf(
                HolidayDto(
                    dateName = "신정",
                    localDate = LocalDate.of(2023, 1, 1),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "설날",
                    localDate = LocalDate.of(2023, 1, 21),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "설날",
                    localDate = LocalDate.of(2023, 1, 22),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "설날",
                    localDate = LocalDate.of(2023, 1, 23),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "대체공휴일",
                    localDate = LocalDate.of(2023, 1, 24),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "삼일절",
                    localDate = LocalDate.of(2023, 3, 1),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "어린이날",
                    localDate = LocalDate.of(2023, 5, 5),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "부처님오신날",
                    localDate = LocalDate.of(2023, 5, 27),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "대체공휴일",
                    localDate = LocalDate.of(2023, 5, 29),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "현충일",
                    localDate = LocalDate.of(2023, 6, 6),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "제헌절",
                    localDate = LocalDate.of(2023, 7, 17),
                    isHoliday = false
                ),
                HolidayDto(
                    dateName = "광복절",
                    localDate = LocalDate.of(2023, 8, 15),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "추석",
                    localDate = LocalDate.of(2023, 9, 28),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "추석",
                    localDate = LocalDate.of(2023, 9, 29),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "추석",
                    localDate = LocalDate.of(2023, 9, 30),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "개천절",
                    localDate = LocalDate.of(2023, 10, 3),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "한글날",
                    localDate = LocalDate.of(2023, 10, 9),
                    isHoliday = true
                ),
                HolidayDto(
                    dateName = "크리스마스",
                    localDate = LocalDate.of(2023, 12, 25),
                    isHoliday = true
                ),
            )
        }

        fun holiday2024Dto(): List<HolidayDto> {
            return listOf(
                HolidayDto(
                    dateName = "신정",
                    localDate = LocalDate.of(2024, 1, 1),
                    isHoliday = true
                )
            )
        }

        fun holiday2023Entity() = holiday2023Dto().map { dto ->
            Holiday(
                dateName = dto.dateName,
                localDate = dto.localDate,
                isHoliday = dto.isHoliday,
            )
        }
    }


}
