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

    val rangeFromDate: LocalDate = calcRangeFrom()
    val rangeFromDateTime: LocalDateTime = rangeFromDate.atStartOfDay()
    val rangeUntilDateTime: LocalDateTime = calcRangeEnd()
    val rangeUntilDate: LocalDate = rangeUntilDateTime.toLocalDate()

    private fun calcRangeFrom(): LocalDate {
        if (paddingBefore == 0) {
            return LocalDate.of(currentMonth.year, currentMonth.monthValue, 1)
        }
        return LocalDate.of(prevMonth.year, prevMonth.monthValue, prevMonth.lengthOfMonth() - paddingBefore + 1)
    }

    private fun calcRangeEnd(): LocalDateTime {
        if (paddingAfter == 0) {
            return LocalDate.of(currentMonth.year, currentMonth.monthValue, lengthOfMonth).atTime(23, 59, 59)
        }
        return LocalDate.of(nextMonth.year, nextMonth.monthValue, paddingAfter).atTime(23, 59, 59)
    }

    fun getRangeYears(): Set<Int> {
        return setOf(prevMonth.year, currentMonth.year, nextMonth.year)
    }

    fun isInRange(holidayDate: LocalDate): Boolean {
        return !holidayDate.isBefore(rangeFromDate) && !holidayDate.isAfter(rangeUntilDate)
    }

    fun getIndex(target: LocalDate): Int {
        if (!isInRange(target)) {
            return -1
        }
        if (target.month == prevMonth.month) {
            return target.dayOfMonth - rangeFromDateTime.dayOfMonth
        }
        if (target.month == currentMonth.month) {
            return paddingBefore + (target.dayOfMonth - 1)
        }
        return paddingBefore + lengthOfMonth + target.dayOfMonth - 1
    }

    fun getRangeDate(): Sequence<LocalDate> {
        return generateSequence(rangeFromDate) { it.plusDays(1) }
            .takeWhile { it <= rangeUntilDate }
    }

    fun getDays(): List<LocalDate> {
        return getRangeDate().toList()
    }

}
