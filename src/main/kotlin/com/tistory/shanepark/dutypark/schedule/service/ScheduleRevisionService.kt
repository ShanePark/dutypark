package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.*
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.entity.ScheduleRevision
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRevisionRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import tools.jackson.databind.json.JsonMapper
import java.time.LocalDateTime
import java.util.UUID

@Service
class ScheduleRevisionService(
    private val revisionRepository: ScheduleRevisionRepository,
    private val attachmentRepository: AttachmentRepository,
    private val objectMapper: JsonMapper,
) {
    fun capture(schedule: Schedule): ScheduleSnapshot = ScheduleSnapshot(
        content = schedule.content,
        displayContent = schedule.content(),
        description = schedule.description,
        startDateTime = schedule.startDateTime,
        endDateTime = schedule.endDateTime,
        visibility = schedule.visibility,
        ownerMemberId = schedule.member.id!!,
        tags = schedule.tags.map { ScheduleMemberSnapshot(it.member.id!!, it.member.name) }.sortedBy { it.id },
        attachments = attachmentRepository.findAllByContextTypeAndContextId(AttachmentContextType.SCHEDULE, schedule.id.toString())
            .sortedWith(compareBy({ it.orderIndex }, { it.id }))
            .map { ScheduleAttachmentSnapshot(it.id, it.originalFilename, it.orderIndex) },
    )

    fun ensureBaseline(schedule: Schedule, snapshot: ScheduleSnapshot = capture(schedule)) {
        if (revisionRepository.findByScheduleIdAndVersion(schedule.id, schedule.version) == null) {
            save(schedule, snapshot, null, "BASELINE")
        }
    }

    fun recordCreation(schedule: Schedule, actor: LoginMember) {
        schedule.version = 1
        save(schedule, capture(schedule), actor, "HUMAN")
    }

    fun recordChange(schedule: Schedule, before: ScheduleSnapshot, actor: LoginMember?, source: String = "HUMAN"): ScheduleSnapshot {
        val after = capture(schedule)
        if (before == after) return after
        ensureBaseline(schedule, before)
        schedule.version += 1
        if (actor != null && source == "HUMAN") {
            schedule.lastEditedById = actor.id
            schedule.lastEditedByName = actor.name
            schedule.lastEditedAt = LocalDateTime.now()
        }
        save(schedule, after, actor, source)
        return after
    }

    fun deleteAll(schedule: Schedule) {
        revisionRepository.deleteAll(revisionRepository.findAllByScheduleIdOrderByVersionAsc(schedule.id))
    }

    fun findRevision(schedule: Schedule, version: Long): ScheduleRevision =
        revisionRepository.findByScheduleIdAndVersion(schedule.id, version)
            ?: throw NoSuchElementException("schedule.version.notFound")

    fun snapshot(revision: ScheduleRevision): ScheduleSnapshot =
        objectMapper.readValue(revision.snapshotJson, ScheduleSnapshot::class.java)

    fun delegatedScheduleIds(scheduleIds: Collection<UUID>): Set<UUID> =
        if (scheduleIds.isEmpty()) emptySet() else revisionRepository.findDelegatedScheduleIds(scheduleIds)

    fun canBlockWithReport(schedule: Schedule): Boolean = schedule.id !in delegatedScheduleIds(listOf(schedule.id))

    fun canReport(schedule: Schedule, viewerId: Long): Boolean =
        schedule.member.id != viewerId || schedule.id in delegatedScheduleIds(listOf(schedule.id))

    fun evidenceFor(schedule: Schedule, version: Long?): ScheduleReportEvidence {
        ensureBaseline(schedule)
        val revision = findRevision(schedule, version ?: schedule.version)
        return ScheduleReportEvidence(
            version = revision.version,
            snapshot = snapshot(revision),
            history = revisionRepository.findAllByScheduleIdAndVersionLessThanEqualOrderByVersionAsc(schedule.id, revision.version)
                .map { ScheduleRevisionEvidence(it.version, it.actorId, it.actorName, it.source, it.createdDate, snapshot(it)) },
        )
    }

    private fun save(schedule: Schedule, snapshot: ScheduleSnapshot, actor: LoginMember?, source: String) {
        revisionRepository.save(ScheduleRevision(schedule, schedule.version, actor?.id, actor?.name, source, objectMapper.writeValueAsString(snapshot)))
    }
}
