package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto.Companion.ofSimple
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.*

data class ScheduleDto(
    val id: UUID,
    val content: String,
    val position: Int,
    val year: Int,
    val month: Int,
    val dayOfMonth: Int,
    val daysFromStart: Int,
    val totalDays: Int,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
    val isTagged: Boolean,
    val tags: List<MemberDto>
) {
    companion object {
        fun of(calendarView: CalendarView, schedule: Schedule, isTagged: Boolean = false): List<ScheduleDto> {
            val startDateTime = schedule.startDateTime
            val startDate = startDateTime.toLocalDate()
            val endDateTime = schedule.endDateTime
            val endDate = endDateTime.toLocalDate()

            val totalDays = ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1
            val validDays = validDays(startDate, endDate, calendarView)
            val tags = schedule.tags.map { t -> ofSimple(t.member) }

            return validDays.map {
                ScheduleDto(
                    id = schedule.id,
                    content = schedule.content,
                    position = schedule.position,
                    year = it.year,
                    month = it.monthValue,
                    dayOfMonth = it.dayOfMonth,
                    daysFromStart = ChronoUnit.DAYS.between(startDate, it).toInt() + 1,
                    totalDays = totalDays,
                    startDateTime = startDateTime,
                    endDateTime = endDateTime,
                    isTagged = isTagged,
                    tags = tags
                )
            }
        }

        private fun validDays(
            startDate: LocalDate,
            endDate: LocalDate,
            calendarView: CalendarView,
        ): MutableList<LocalDate> {
            val rangeFrom = calendarView.rangeFrom.toLocalDate()
            var current = startDate
            if (current.isBefore(rangeFrom))
                current = rangeFrom

            val daysInRange = mutableListOf<LocalDate>()
            while (validDate(current, endDate, calendarView.rangeEnd.toLocalDate())) {
                daysInRange.add(current)
                current = current.plusDays(1)
            }
            return daysInRange
        }

        private fun validDate(
            current: LocalDate,
            endDate: LocalDate,
            limitRangeUntil: LocalDate,
        ) = !current.isAfter(endDate) && !current.isAfter(limitRangeUntil)
    }
}
