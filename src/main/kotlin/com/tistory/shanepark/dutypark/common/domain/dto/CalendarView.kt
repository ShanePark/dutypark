package com.tistory.shanepark.dutypark.common.domain.dto

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

class CalendarView(yearMonth: YearMonth) {
    val prevMonth: YearMonth = yearMonth.minusMonths(1)
    val paddingBefore = yearMonth.atDay(1).dayOfWeek.value % 7

    val currentMonth: YearMonth = yearMonth
    val lengthOfMonth = yearMonth.lengthOfMonth()

    val nextMonth: YearMonth = yearMonth.plusMonths(1)
    val paddingAfter = 7 - (yearMonth.atDay(lengthOfMonth).dayOfWeek.value % 7 + 1)

    val size = paddingBefore + lengthOfMonth + paddingAfter
    val rangeFrom: LocalDateTime =
        LocalDate.of(prevMonth.year, prevMonth.monthValue, prevMonth.lengthOfMonth() - paddingBefore + 1)
            .atStartOfDay()
    val rangeEnd: LocalDateTime = LocalDate.of(nextMonth.year, nextMonth.monthValue, paddingAfter).atTime(23, 59, 59)
}
