package com.tistory.shanepark.dutypark.duty.batch

import java.time.LocalDate

class BatchParseResult(
    val startDate: LocalDate,
    val endDate: LocalDate,
    private val result: Map<String, List<LocalDate>>
) {
    fun getNames(): Set<String> {
        return result.keys
    }

    fun getOffDays(name: String): List<LocalDate> {
        return result[name] ?: throw IllegalArgumentException("Name not found")
    }

    fun getWorkDays(name: String): List<LocalDate> {
        val offDays = getOffDays(name)
        return startDate.datesUntil(endDate)
            .filter { it !in offDays }
            .toList()
    }

}
