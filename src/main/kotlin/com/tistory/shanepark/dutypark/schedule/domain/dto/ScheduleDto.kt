package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto.Companion.ofSimple
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.*

data class ScheduleDto(
    val id: UUID,
    val content: String,
    val description: String,
    val position: Int,
    val year: Int,
    val month: Int,
    val dayOfMonth: Int,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
    val isTagged: Boolean,
    val owner: String,
    val tags: List<MemberDto> = listOf(),
    val visibility: Visibility? = null,
    val dateToCompare: LocalDate,
) {
    val startDate: LocalDate = startDateTime.toLocalDate()
    val daysFromStart = ChronoUnit.DAYS.between(startDate, dateToCompare).toInt() + 1
    val endDate: LocalDate = endDateTime.toLocalDate()
    val curDate: LocalDate = LocalDate.of(year, month, dayOfMonth)
    val totalDays = ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1

    companion object {
        fun ofSimple(member: Member, schedule: Schedule, dateToCompare: LocalDate): ScheduleDto {
            return ScheduleDto(
                id = schedule.id,
                content = schedule.content(),
                description = schedule.description,
                position = schedule.position,
                year = schedule.startDateTime.year,
                month = schedule.startDateTime.monthValue,
                dayOfMonth = schedule.startDateTime.dayOfMonth,
                startDateTime = schedule.startDateTime,
                endDateTime = schedule.endDateTime,
                isTagged = schedule.member.id != member.id,
                owner = schedule.member.name,
                dateToCompare = dateToCompare,
            )
        }

        fun of(calendarView: CalendarView, schedule: Schedule, isTagged: Boolean = false): List<ScheduleDto> {
            val startDate = schedule.startDateTime.toLocalDate()
            val endDate = schedule.endDateTime.toLocalDate()
            val tags = schedule.tags.map { t -> ofSimple(t.member) }

            return calendarView.validDays(startDate = startDate, endDate = endDate)
                .map {
                    ScheduleDto(
                        id = schedule.id,
                        content = schedule.content(),
                        description = schedule.description,
                        position = schedule.position,
                        year = it.year,
                        month = it.monthValue,
                        dayOfMonth = it.dayOfMonth,
                        startDateTime = schedule.startDateTime,
                        endDateTime = schedule.endDateTime,
                        isTagged = isTagged,
                        owner = schedule.member.name,
                        tags = tags,
                        visibility = schedule.visibility,
                        dateToCompare = it,
                    )
                }
        }
    }
}
