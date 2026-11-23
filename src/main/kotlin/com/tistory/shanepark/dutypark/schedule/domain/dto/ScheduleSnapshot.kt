package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import java.time.LocalDateTime
import java.util.UUID

data class ScheduleMemberSnapshot(val id: Long, val name: String)
data class ScheduleAttachmentSnapshot(val id: UUID, val originalFilename: String, val orderIndex: Int)

data class ScheduleSnapshot(
    val content: String,
    val displayContent: String,
    val description: String,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
    val visibility: Visibility,
    val ownerMemberId: Long,
    val tags: List<ScheduleMemberSnapshot>,
    val attachments: List<ScheduleAttachmentSnapshot>,
) {
    fun hasNotifiableChanges(other: ScheduleSnapshot): Boolean =
        displayContent != other.displayContent || description != other.description ||
            startDateTime != other.startDateTime || endDateTime != other.endDateTime
}

data class ScheduleRevisionEvidence(
    val version: Long,
    val actorId: Long?,
    val actorName: String?,
    val source: String,
    val editedAt: LocalDateTime,
    val snapshot: ScheduleSnapshot,
)

data class ScheduleReportEvidence(
    val version: Long,
    val snapshot: ScheduleSnapshot,
    val history: List<ScheduleRevisionEvidence>,
)
