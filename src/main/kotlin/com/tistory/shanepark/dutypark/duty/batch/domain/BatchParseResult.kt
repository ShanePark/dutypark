package com.tistory.shanepark.dutypark.duty.batch.domain

import java.time.LocalDate

class BatchParseResult(
    val startDate: LocalDate,
    val endDate: LocalDate,
    private val offDayResult: Map<String, Set<LocalDate>>
) {
    private val _workTimeTable: LinkedHashMap<LocalDate, List<String>> = LinkedHashMap()
    val workTimeTable: Map<LocalDate, List<String>> = _workTimeTable.toMap()

    private val _offTimeTable: LinkedHashMap<LocalDate, List<String>> = LinkedHashMap()
    val offTimeTable: Map<LocalDate, List<String>> = _offTimeTable.toMap()

    init {
        val dateRange = startDate.datesUntil(endDate.plusDays(1)).toList()
        dateRange.forEach { date ->
            val names = offDayResult.filter { it.value.contains(date) }.keys.toList()
            _offTimeTable[date] = names
            _workTimeTable[date] = offDayResult.keys.toList() - names.toSet()
        }
    }

    fun getNames(): List<String> {
        return offDayResult.keys.toList()
    }

    fun getOffDays(name: String): List<LocalDate> {
        val offDays = offDayResult[name] ?: throw IllegalArgumentException("Name not found")
        return offDays.sorted().toList()
    }

    fun getWorkDays(name: String): List<LocalDate> {
        val offDays = getOffDays(name).toSet()
        return startDate.datesUntil(endDate.plusDays(1))
            .filter { it !in offDays }
            .sorted()
            .toList()
    }

    fun findValidNames(name: String): List<String> {
        return this.getNames()
            .filter { name == it || name.endsWith(it) }
            .toList()
    }

}
