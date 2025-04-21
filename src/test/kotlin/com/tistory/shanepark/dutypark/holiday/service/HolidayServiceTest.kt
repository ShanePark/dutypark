package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.Holiday
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPI
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import java.time.LocalDate

@ExtendWith(MockitoExtension::class)
class HolidayServiceTest {

    @InjectMocks
    lateinit var holidayService: HolidayService

    @Mock
    lateinit var holidayAPI: HolidayAPI

    @Mock
    lateinit var holidayRepository: HolidayRepository

    @Test
    fun `findHolidaysTest-loadFromMemory`() {
        // Given
        val calendarView = CalendarView(2023, 5)
        HolidayService::class.java.getDeclaredField("holidayMap").apply {
            isAccessible = true
            set(holidayService, mutableMapOf(2023 to holiday2023Dto()))
        }

        // When
        val result = holidayService.findHolidays(calendarView)

        // Then
        assert2023MayResult(result)
    }

    @Test
    fun `findHolidaysTest-loadFromDB`() {
        // Given
        val calendarView = CalendarView(2023, 5)

        // When
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any()))
            .thenReturn(holiday2023Entity())
        val result = holidayService.findHolidays(calendarView)

        // Then
        assert2023MayResult(result)
    }

    @Test
    fun `findHolidaysTest-loadFromAPI`() {
        // Given
        val calendarView = CalendarView(2023, 5)

        // When
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(any())).thenReturn(holiday2023Dto())
        val result = holidayService.findHolidays(calendarView)

        // Then
        assert2023MayResult(result)
    }

    @Test
    fun `test december 2023`() {
        // Given
        val calendarView = CalendarView(2023, 12)

        // When
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(listOf())
        `when`(holidayAPI.requestHolidays(2023)).thenReturn(holiday2023Dto())
        `when`(holidayAPI.requestHolidays(2024)).thenReturn(holiday2024Dto())
        val result = holidayService.findHolidays(calendarView)

        for (i in result.indices) {
            print("result[$i]: ${result[i]}  ")
            if (i % 7 == 6) println()
        }
        assert2023DecemberResult(result)
    }

    private fun assert2023MayResult(result: Array<List<HolidayDto>>) {
        assertThat(result.size).isEqualTo(35)
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
