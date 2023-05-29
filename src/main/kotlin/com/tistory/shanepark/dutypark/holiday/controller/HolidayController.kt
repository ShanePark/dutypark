package com.tistory.shanepark.dutypark.holiday.controller

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.YearMonth

@RestController
@RequestMapping("/api/holiday")
class HolidayController(
    private val holidayService: HolidayService
) {

    @GetMapping
    fun getHolidays(@RequestParam year: Int, @RequestParam month: Int): Array<List<HolidayDto>> {
        val yearMonth = YearMonth.of(year, month)
        val calendarView = CalendarView(yearMonth = yearMonth)
        return holidayService.findHolidays(calendarView = calendarView)
    }

}
