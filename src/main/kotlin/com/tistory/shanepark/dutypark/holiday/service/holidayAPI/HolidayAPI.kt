package com.tistory.shanepark.dutypark.holiday.service.holidayAPI

import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto

interface HolidayAPI {

    fun requestHolidays(year: Int): List<HolidayDto>
}
