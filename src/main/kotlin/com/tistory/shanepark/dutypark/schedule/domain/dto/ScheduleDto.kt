package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.*

data class ScheduleDto(
    val id: UUID,
    val content: String,
    val position: Int,
    val month: Int,
    val dayOfMonth: Int,
    val daysFromStart: Int,
    val totalDays: Int,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
) {
    companion object {
        fun of(calendarView: CalendarView, schedule: Schedule): List<ScheduleDto> {
            val startDate = schedule.startDateTime
            val endDate = schedule.endDateTime
            val totalDays = ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1
            val validDays = validDays(startDate, endDate, calendarView)

            return validDays.map {
                ScheduleDto(
                    id = schedule.id,
                    content = schedule.content,
                    position = schedule.position,
                    month = it.monthValue,
                    dayOfMonth = it.dayOfMonth,
                    daysFromStart = ChronoUnit.DAYS.between(startDate.toLocalDate(), it).toInt() + 1,
                    totalDays = totalDays,
                    startDateTime = startDate,
                    endDateTime = endDate,
                )
            }
        }

        private fun validDays(
            startDate: LocalDateTime,
            endDate: LocalDateTime,
            calendarView: CalendarView,
        ): MutableList<LocalDate> {
            val rangeFrom = calendarView.rangeFrom
            var current = startDate
            if (current.isBefore(rangeFrom))
                current = rangeFrom

            val daysInRange = mutableListOf<LocalDate>()
            while (validDate(current, endDate, calendarView.rangeEnd)) {
                daysInRange.add(current.toLocalDate())
                current = current.plusDays(1)
            }
            return daysInRange
        }

        private fun validDate(
            current: LocalDateTime,
            endDate: LocalDateTime,
            limitRangeUntil: LocalDateTime,
        ) = !current.isAfter(endDate) && !current.isAfter(limitRangeUntil)
    }
}
