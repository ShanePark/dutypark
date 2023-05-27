package com.tistory.shanepark.dutypark.holiday.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.repository.HolidayRepository
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPI
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.jupiter.MockitoExtension
import java.time.YearMonth

@ExtendWith(MockitoExtension::class)
class HolidayServiceTest {

    @InjectMocks
    lateinit var holidayService: HolidayService

    @Test
    fun `findHolidaysTest-loadFromMemory`(
        @Mock holidayAPI: HolidayAPI,
        @Mock holidayRepository: HolidayRepository
    ) {
        // TODO: Implement
    }

    @Test
    fun `findHolidaysTest-loadFromDB`(
        @Mock holidayAPI: HolidayAPI,
        @Mock holidayRepository: HolidayRepository
    ) {
        // TODO: Implement
    }

    //    @Test
    fun `findHolidaysTest-loadFromAPI`(
        @Mock holidayAPI: HolidayAPI,
        @Mock holidayRepository: HolidayRepository
    ) {
        `when`(holidayRepository.findAllByLocalDateBetween(any(), any())).thenReturn(emptyList())
        `when`(holidayAPI.requestHolidays(any())).thenReturn(holiday2023())

        val yearMonth = YearMonth.of(2023, 5)
        val calendarView = CalendarView(yearMonth)
        val result = holidayService.findHolidays(calendarView)
        assertThat(result[5]).hasSize(1)
        // TODO: Working In Progress
    }

    private fun holiday2023(): List<HolidayDto> {
        // TODO: 2023 Holiday List
        return listOf()
    }

}
