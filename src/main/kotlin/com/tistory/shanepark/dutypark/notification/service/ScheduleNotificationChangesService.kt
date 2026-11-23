package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.common.exceptions.ForbiddenException
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleUpdatedPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import com.tistory.shanepark.dutypark.notification.dto.ScheduleNotificationChangesDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRevisionRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.service.ScheduleRevisionService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class ScheduleNotificationChangesService(
    private val notificationRepository: NotificationRepository,
    private val payloadCodec: NotificationPayloadCodec,
    private val scheduleRepository: ScheduleRepository,
    private val revisionService: ScheduleRevisionService,
    private val blockService: BlockService,
    private val revisionRepository: ScheduleRevisionRepository,
) {
    @Transactional(readOnly = true)
    fun getChanges(viewer: LoginMember, notificationId: UUID): ScheduleNotificationChangesDto {
        val notification = notificationRepository.findByMemberIdAndId(viewer.id, notificationId)
            ?.takeIf { it.type == NotificationType.SCHEDULE_UPDATED && it.referenceType == NotificationReferenceType.SCHEDULE }
            ?: throw NoSuchElementException("common.notFound")
        val payload = (payloadCodec.safeDeserialize(notification.type, notification.payloadVersion, notification.payloadJson)
            as? NotificationPayloadDecodeResult.Success)?.payload as? ScheduleUpdatedPayload
            ?: throw NoSuchElementException("common.notFound")
        val scheduleId = notification.referenceId?.let(UUID::fromString) ?: throw NoSuchElementException("common.notFound")
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        if (!canAccess(viewer.id, schedule, notification.actorId)) {
            throw ForbiddenException("schedule.visibility.forbidden")
        }
        val before = revisionService.snapshot(revisionService.findRevision(schedule, payload.scheduleVersion - 1))
        val after = revisionService.snapshot(revisionService.findRevision(schedule, payload.scheduleVersion))
        return ScheduleNotificationChangesDto.between(schedule.id, payload.scheduleVersion, before, after)
    }

    fun enrich(memberId: Long, notifications: List<NotificationDto>): List<NotificationDto> {
        val updates = notifications.filter {
            it.type == NotificationType.SCHEDULE_UPDATED && it.referenceType == NotificationReferenceType.SCHEDULE &&
                it.payload is ScheduleUpdatedPayload && it.referenceId != null
        }
        if (updates.isEmpty()) return notifications
        val scheduleIds = updates.mapNotNull { runCatching { UUID.fromString(it.referenceId) }.getOrNull() }.toSet()
        if (scheduleIds.isEmpty()) return notifications
        val schedules = scheduleRepository.findAllWithMemberAndTagsByIdIn(scheduleIds).associateBy { it.id }
        val blockedMembers = mutableMapOf<Long, Boolean>()
        val accessible = updates.filter { notification ->
            val schedule = schedules[runCatching { UUID.fromString(notification.referenceId) }.getOrNull()]
            schedule != null && canAccess(memberId, schedule, notification.actorId, blockedMembers)
        }
        if (accessible.isEmpty()) return notifications
        val revisions = accessible.groupBy { UUID.fromString(it.referenceId) }.flatMap { (scheduleId, updates) ->
            val versions = updates.flatMap {
                val version = (it.payload as ScheduleUpdatedPayload).scheduleVersion
                listOf(version - 1, version)
            }.toSet()
            revisionRepository.findAllByScheduleIdAndVersionIn(scheduleId, versions)
        }.associate { (it.schedule.id to it.version) to revisionService.snapshot(it) }
        val changes = accessible.mapNotNull { notification ->
            val scheduleId = UUID.fromString(notification.referenceId)
            val version = (notification.payload as ScheduleUpdatedPayload).scheduleVersion
            val before = revisions[scheduleId to version - 1] ?: return@mapNotNull null
            val after = revisions[scheduleId to version] ?: return@mapNotNull null
            notification.id to ScheduleNotificationChangesDto.between(
                scheduleId, version, before, after,
            )
        }.toMap()
        return notifications.map { it.copy(scheduleChanges = changes[it.id]) }
    }

    private fun canAccess(
        viewerId: Long,
        schedule: Schedule,
        actorId: Long?,
        blockedMembers: MutableMap<Long, Boolean> = mutableMapOf(),
    ): Boolean {
        val isOwner = schedule.member.id == viewerId
        if (!isOwner && schedule.tags.none { it.member.id == viewerId }) return false
        fun isBlocked(memberId: Long) = blockedMembers.getOrPut(memberId) {
            blockService.isBlockedEitherWay(viewerId, memberId)
        }
        return (isOwner || !isBlocked(schedule.member.id!!)) && (actorId == null || !isBlocked(actorId))
    }
}
