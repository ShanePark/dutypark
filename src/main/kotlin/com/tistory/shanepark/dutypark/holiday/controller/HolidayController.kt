package com.tistory.shanepark.dutypark.holiday.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.cache.annotation.Cacheable
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/holidays")
class HolidayController(
    private val holidayService: HolidayService
) {
    private val log = logger()

    @GetMapping
    @Cacheable(value = ["holidays"], key = "#year + '-' + #month")
    fun getHolidays(@RequestParam year: Int, @RequestParam month: Int): Array<List<HolidayDto>> {
        val calendarView = CalendarView(year = year, month = month)
        return holidayService.findHolidays(calendarView = calendarView)
    }

    @DeleteMapping
    fun resetHolidayInfo(@Login loginMember: LoginMember) {
        if (loginMember.isAdmin.not()) {
            log.warn("Only admin can access this API. : {}", loginMember)
            throw IllegalAccessException()
        }
        holidayService.resetHolidayInfo()
    }

}
