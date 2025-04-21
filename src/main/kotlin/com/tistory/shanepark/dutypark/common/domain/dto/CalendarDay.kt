package com.tistory.shanepark.dutypark.common.domain.dto

import java.time.LocalDate

data class CalendarDay(
    val year: Int,
    val month: Int,
    val day: Int,
) {

    constructor(date: LocalDate) : this(
        year = date.year,
        month = date.monthValue,
        day = date.dayOfMonth
    )

    companion object {
        fun of(calendarView: CalendarView): List<CalendarDay> {
            return calendarView.dates.map { CalendarDay(it) }
        }
    }

}
