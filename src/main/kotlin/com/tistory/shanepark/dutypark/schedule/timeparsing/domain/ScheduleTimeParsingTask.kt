package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.time.LocalDateTime
import java.util.*

data class ScheduleTimeParsingTask(
    val scheduleId: UUID,
) {
    private val requestDateTime: LocalDateTime = LocalDateTime.now()

    fun isExpired(schedule: Schedule): Boolean {
        if (schedule.id != scheduleId) {
            throw IllegalArgumentException("Schedule ID does not match: ${schedule.id} != $scheduleId")
        }
        return schedule.lastModifiedDate.isAfter(requestDateTime)
    }
}

