package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import java.util.*

class ScheduleTimeParsingTask(schedule: Schedule) {
    val scheduleId: UUID = schedule.id
    val parsingGeneration: UUID = schedule.parsingGeneration
    private var unexpectedFailureCount: Int = 0

    fun isExpired(schedule: Schedule): Boolean {
        if (schedule.id != scheduleId) {
            throw IllegalArgumentException("Schedule ID does not match: ${schedule.id} != $scheduleId")
        }

        return schedule.parsingGeneration != parsingGeneration
    }

    fun canRetryAfterUnexpectedFailure(maxAttempts: Int = 3): Boolean {
        unexpectedFailureCount++
        return unexpectedFailureCount < maxAttempts
    }

}
