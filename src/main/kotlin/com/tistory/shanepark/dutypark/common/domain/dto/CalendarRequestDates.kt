package com.tistory.shanepark.dutypark.common.domain.dto

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import java.time.LocalDate
import java.time.YearMonth

/**
 * Converts client-supplied year/month/day values into dates, rejecting values outside the supported range
 * with a bad request instead of letting java.time or the database fail with a server error.
 */
object CalendarRequestDates {
    const val MIN_YEAR = 1

    // A December calendar pads into January of the next year, and MySQL DATETIME cannot represent year 10000.
    const val MAX_YEAR = 9998

    fun yearMonth(year: Int, month: Int): YearMonth {
        if (year !in MIN_YEAR..MAX_YEAR || month !in 1..12) {
            throw BadRequestException()
        }
        return YearMonth.of(year, month)
    }

    fun date(year: Int, month: Int, day: Int): LocalDate {
        val yearMonth = yearMonth(year, month)
        if (!yearMonth.isValidDay(day)) {
            throw BadRequestException()
        }
        return yearMonth.atDay(day)
    }

    fun calendarView(year: Int, month: Int): CalendarView {
        yearMonth(year, month)
        return CalendarView(year = year, month = month)
    }
}
