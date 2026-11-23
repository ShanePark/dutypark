package com.tistory.shanepark.dutypark.schedule.event

import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSnapshot
import java.util.UUID

data class ScheduleUpdatedEvent(
    val scheduleId: UUID,
    val ownerId: Long,
    val actorId: Long,
    val scheduleVersion: Long,
    val before: ScheduleSnapshot,
    val after: ScheduleSnapshot,
)
