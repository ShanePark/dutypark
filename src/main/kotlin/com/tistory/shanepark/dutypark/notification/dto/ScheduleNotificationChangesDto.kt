package com.tistory.shanepark.dutypark.notification.dto

import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSnapshot
import java.time.LocalDateTime
import java.util.UUID

data class ScheduleTextChange(val before: String, val after: String)

data class ScheduleTimeSnapshot(val startDateTime: LocalDateTime, val endDateTime: LocalDateTime)

data class ScheduleTimeChange(val before: ScheduleTimeSnapshot, val after: ScheduleTimeSnapshot)

data class ScheduleNotificationChangesDto(
    val scheduleId: UUID,
    val scheduleVersion: Long,
    val scheduleTitle: String,
    val title: ScheduleTextChange?,
    val description: ScheduleTextChange?,
    val time: ScheduleTimeChange?,
) {
    val changedFields: List<String>
        get() = buildList {
            if (title != null) add("TITLE")
            if (description != null) add("DESCRIPTION")
            if (time != null) add("TIME")
        }

    companion object {
        fun between(id: UUID, version: Long, before: ScheduleSnapshot, after: ScheduleSnapshot): ScheduleNotificationChangesDto =
            ScheduleNotificationChangesDto(
                scheduleId = id,
                scheduleVersion = version,
                scheduleTitle = after.displayContent,
                title = if (before.displayContent != after.displayContent) ScheduleTextChange(before.displayContent, after.displayContent) else null,
                description = if (before.description != after.description) ScheduleTextChange(before.description, after.description) else null,
                time = if (before.startDateTime != after.startDateTime || before.endDateTime != after.endDateTime) {
                    ScheduleTimeChange(
                        ScheduleTimeSnapshot(before.startDateTime, before.endDateTime),
                        ScheduleTimeSnapshot(after.startDateTime, after.endDateTime),
                    )
                } else null,
            )
    }
}
