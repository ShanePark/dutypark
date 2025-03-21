package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.*

data class TeamScheduleDto(
    val id: UUID,
    val content: String,
    val description: String,
    val position: Int,
    val year: Int,
    val month: Int,
    val dayOfMonth: Int,
    val daysFromStart: Int? = null,
    val totalDays: Int? = null,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
    val createMember: String,
    val updateMember: String,
) {
    companion object {
        fun ofSimple(schedule: TeamSchedule): TeamScheduleDto {
            return TeamScheduleDto(
                id = schedule.id,
                content = schedule.content,
                description = schedule.description,
                position = schedule.position,
                year = schedule.startDateTime.year,
                month = schedule.startDateTime.monthValue,
                dayOfMonth = schedule.startDateTime.dayOfMonth,
                startDateTime = schedule.startDateTime,
                endDateTime = schedule.endDateTime,
                createMember = schedule.createMember.name,
                updateMember = schedule.updateMember.name,
            )
        }

        fun of(calendar: CalendarView, schedule: TeamSchedule): List<TeamScheduleDto> {
            val startDate = schedule.startDateTime.toLocalDate()
            val endDate = schedule.endDateTime.toLocalDate()
            val totalDays = ChronoUnit.DAYS.between(startDate, endDate).toInt() + 1

            return calendar.validDays(startDate, endDate).map {
                TeamScheduleDto(
                    id = schedule.id,
                    content = schedule.content,
                    description = schedule.description,
                    position = schedule.position,
                    year = it.year,
                    month = it.monthValue,
                    dayOfMonth = it.dayOfMonth,
                    daysFromStart = ChronoUnit.DAYS.between(startDate, it).toInt() + 1,
                    totalDays = totalDays,
                    startDateTime = schedule.startDateTime,
                    endDateTime = schedule.endDateTime,
                    createMember = schedule.createMember.name,
                    updateMember = schedule.updateMember.name,
                )
            }
        }
    }
}
