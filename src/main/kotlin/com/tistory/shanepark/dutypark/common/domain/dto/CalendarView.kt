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
    val rangeFrom: LocalDateTime = calcRangeProm()
    val rangeEnd: LocalDateTime = calcRangeEnd()

    private fun calcRangeProm(): LocalDateTime {
        if (paddingBefore == 0) {
            return LocalDate.of(currentMonth.year, currentMonth.monthValue, 1).atStartOfDay()
        }
        return LocalDate.of(prevMonth.year, prevMonth.monthValue, prevMonth.lengthOfMonth() - paddingBefore + 1)
            .atStartOfDay()
    }

    private fun calcRangeEnd(): LocalDateTime {
        if (paddingAfter == 0) {
            return LocalDate.of(currentMonth.year, currentMonth.monthValue, lengthOfMonth).atTime(23, 59, 59)
        }
        return LocalDate.of(nextMonth.year, nextMonth.monthValue, paddingAfter).atTime(23, 59, 59)
    }

    fun getRangeYears(): Set<Int> {
        val set = HashSet<Int>()
        set.add(prevMonth.year)
        set.add(currentMonth.year)
        set.add(nextMonth.year)
        return set
    }

    fun isInRange(holidayDate: LocalDate): Boolean {
        return !holidayDate.isBefore(rangeFrom.toLocalDate()) && !holidayDate.isAfter(rangeEnd.toLocalDate())
    }

    fun getIndex(target: LocalDate): Int {
        if (!isInRange(target)) {
            return -1
        }
        if (target.month == prevMonth.month) {
            return target.dayOfMonth - rangeFrom.dayOfMonth
        }
        if (target.month == currentMonth.month) {
            return paddingBefore + (target.dayOfMonth - 1)
        }
        return paddingBefore + lengthOfMonth + target.dayOfMonth
    }

}
