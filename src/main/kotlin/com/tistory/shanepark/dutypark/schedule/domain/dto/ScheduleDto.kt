package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.util.*

data class ScheduleDto(
    val id: UUID,
    val content: String,
    val position: Int,
    val dayOfMonth: Int,
    val daysFromStart: Int,
    val totalDays: Int,
) {
    companion object {
        fun of(yearMonth: YearMonth, schedule: Schedule): List<ScheduleDto> {
            val startDate = schedule.startDateTime
            val endDate = schedule.endDateTime
            val totalDays = ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1

            return validDays(startDate, endDate, yearMonth).map {
                ScheduleDto(
                    id = schedule.id,
                    content = schedule.content,
                    position = schedule.position,
                    dayOfMonth = it.dayOfMonth,
                    daysFromStart = ChronoUnit.DAYS.between(startDate.toLocalDate(), it).toInt() + 1,
                    totalDays = totalDays
                )
            }
        }

        private fun validDays(
            startDate: LocalDateTime,
            endDate: LocalDateTime,
            yearMonth: YearMonth
        ): MutableList<LocalDate> {
            val daysInRange = mutableListOf<LocalDate>()
            var current = startDate.toLocalDate()
            while (!current.isAfter(endDate.toLocalDate())) {
                if (current.year == yearMonth.year && current.monthValue == yearMonth.monthValue) {
                    daysInRange.add(current)
                }
                current = current.plusDays(1)
            }
            return daysInRange
        }
    }
}
