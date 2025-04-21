package com.tistory.shanepark.dutypark.common.domain.dto

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth

class CalendarView(val year: Int, val month: Int) {
    val yearMonth: YearMonth = YearMonth.of(year, month)

    private val paddingBefore: Int = yearMonth.atDay(1).dayOfWeek.value % 7
    private val paddingAfter: Int = 7 - (yearMonth.atEndOfMonth().dayOfWeek.value % 7 + 1)
    val size: Int = paddingBefore + yearMonth.lengthOfMonth() + paddingAfter

    val startDate: LocalDate = yearMonth.atDay(1).minusDays(paddingBefore.toLong())
    val endDate: LocalDate = yearMonth.atEndOfMonth().plusDays(paddingAfter.toLong())

    val rangeFromDateTime: LocalDateTime = startDate.atStartOfDay()
    val rangeUntilDateTime: LocalDateTime = endDate.atTime(23, 59, 59)

    val dates: List<LocalDate> by lazy {
        (0 until size).map { startDate.plusDays(it.toLong()) }
    }

    fun isInRange(date: LocalDate): Boolean {
        return !date.isBefore(startDate) && !date.isAfter(endDate)
    }

    fun getIndex(date: LocalDate): Int {
        dates.forEachIndexed { index, d ->
            if (d == date) {
                return index
            }
        }
        throw IndexOutOfBoundsException("Date $date not found in calendar view")
    }

    fun validDays(startDate: LocalDate, endDate: LocalDate): List<LocalDate> {
        return dates
            .filter { !it.isBefore(startDate) && !it.isAfter(endDate) }
            .toList()
    }

    fun <T> makeCalendarArray(): Array<List<T>> {
        return Array(size) { emptyList() }
    }

    override fun toString(): String {
        return "CalendarView(year=$year, month=$month)"
    }


}
