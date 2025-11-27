package com.tistory.shanepark.dutypark.common.domain.dto

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

class CalendarView(val year: Int, val month: Int) {
    companion object {
        const val SIZE: Int = 42
    }

    private val yearMonth: YearMonth = YearMonth.of(year, month)

    private val firstDayOfWeek: Int = yearMonth.atDay(1).dayOfWeek.value % 7
    private val paddingBefore: Int = if (firstDayOfWeek == 0) 7 else firstDayOfWeek

    val startDate: LocalDate = yearMonth.atDay(1).minusDays(paddingBefore.toLong())
    val endDate: LocalDate = startDate.plusDays((SIZE - 1).toLong())

    val rangeFromDateTime: LocalDateTime = startDate.atStartOfDay()
    val rangeUntilDateTime: LocalDateTime = endDate.atTime(23, 59, 59)

    val dates: List<LocalDate> by lazy {
        (0 until SIZE).map { startDate.plusDays(it.toLong()) }
    }

    fun isInRange(date: LocalDate): Boolean {
        return !date.isBefore(startDate) && !date.isAfter(endDate)
    }

    fun getIndex(date: LocalDate): Int {
        val index = dates.indexOf(date)
        if (index == -1) {
            throw IndexOutOfBoundsException("Date $date not found in calendar view")
        }
        return index
    }

    fun validDays(startDate: LocalDate, endDate: LocalDate): List<LocalDate> {
        return dates
            .filter { !it.isBefore(startDate) && !it.isAfter(endDate) }
            .toList()
    }

    fun <T> makeCalendarArray(): Array<List<T>> {
        return Array(SIZE) { emptyList() }
    }

    override fun toString(): String {
        return "CalendarView(year=$year, month=$month)"
    }


}
