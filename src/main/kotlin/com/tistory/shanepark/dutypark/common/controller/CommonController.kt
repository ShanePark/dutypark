package com.tistory.shanepark.dutypark.common.controller

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarDay
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarRequestDates
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api")
class CommonController {

    @GetMapping("/calendar")
    fun loadCalendar(
        @RequestParam year: Int,
        @RequestParam month: Int
    ): List<CalendarDay> {
        val calendarView = CalendarRequestDates.calendarView(year = year, month = month)
        return CalendarDay.of(calendarView)
    }

}
