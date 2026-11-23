package com.tistory.shanepark.dutypark.report.domain.dto

import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleMemberSnapshot
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleReportEvidence
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSnapshot
import java.time.LocalDateTime

data class ScheduleReportChangeDto(
    val version: Long,
    val actorId: Long?,
    val actorName: String?,
    val source: String,
    val editedAt: LocalDateTime,
    val changedFields: List<String>,
)

/** Only the reported contents survive deletion. Earlier revisions contribute authorship metadata. */
data class ScheduleReportEvidenceDto(
    val version: Long,
    val snapshot: ScheduleSnapshot,
    val owner: ScheduleMemberSnapshot,
    val createdBy: ScheduleMemberSnapshot?,
    val history: List<ScheduleReportChangeDto>,
    val fieldAuthors: Map<String, ScheduleReportChangeDto>,
) {
    companion object {
        fun of(evidence: ScheduleReportEvidence, owner: ScheduleMemberSnapshot, createdBy: ScheduleMemberSnapshot?): ScheduleReportEvidenceDto {
            var previous: ScheduleSnapshot? = null
            val fieldAuthors = linkedMapOf<String, ScheduleReportChangeDto>()
            val history = evidence.history.map { revision ->
                val fields = changedFields(previous, revision.snapshot)
                previous = revision.snapshot
                ScheduleReportChangeDto(revision.version, revision.actorId, revision.actorName, revision.source,
                    revision.editedAt, fields).also { change -> fields.forEach { fieldAuthors[it] = change } }
            }
            return ScheduleReportEvidenceDto(evidence.version, evidence.snapshot, owner, createdBy, history, fieldAuthors)
        }

        private fun changedFields(before: ScheduleSnapshot?, after: ScheduleSnapshot): List<String> = buildList {
            if (before?.content != after.content || before?.displayContent != after.displayContent) add("content")
            if (before?.description != after.description) add("description")
            if (before?.startDateTime != after.startDateTime) add("startDateTime")
            if (before?.endDateTime != after.endDateTime) add("endDateTime")
            if (before?.visibility != after.visibility) add("visibility")
            if (before?.tags != after.tags) add("tags")
            if (before?.attachments != after.attachments) add("attachments")
        }
    }
}
