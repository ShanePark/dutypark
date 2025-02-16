package com.tistory.shanepark.dutypark.duty.batch.domain

import java.time.LocalDate

class BatchParseResult(
    val startDate: LocalDate,
    val endDate: LocalDate,
    private val offDayResult: Map<String, List<LocalDate>>
) {
    fun getNames(): List<String> {
        return offDayResult.keys.toList()
    }

    fun getOffDays(name: String): List<LocalDate> {
        return offDayResult[name] ?: throw IllegalArgumentException("Name not found")
    }

    fun getWorkDays(name: String): List<LocalDate> {
        val offDays = getOffDays(name)
        return startDate.datesUntil(endDate)
            .filter { it !in offDays }
            .toList()
    }

}
