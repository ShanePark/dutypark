package com.tistory.shanepark.dutypark.holiday.domain

import java.time.LocalDate

data class HolidayDto(
    val dateName: String,
    val isHoliday: Boolean,
    val localDate: LocalDate
) {
    companion object {
        fun of(it: Holiday): HolidayDto {
            return HolidayDto(it.dateName, it.isHoliday, it.localDate)
        }
    }
}
