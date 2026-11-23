package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleUpdatedPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.dto.ScheduleNotificationChangesDto
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.schedule.event.ScheduleUpdatedEvent
import org.springframework.context.ApplicationEventPublisher
import org.springframework.context.event.EventListener
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional

@Component
class ScheduleUpdateNotificationListener(
    private val notificationService: NotificationService,
    private val notificationRepository: NotificationRepository,
    private val memberRepository: MemberRepository,
    private val blockService: BlockService,
    private val eventPublisher: ApplicationEventPublisher,
) {
    @EventListener
    @Transactional(propagation = Propagation.MANDATORY)
    fun handleScheduleUpdated(event: ScheduleUpdatedEvent) {
        if (event.before.tags.isEmpty() && event.after.tags.isEmpty()) return
        val changes = ScheduleNotificationChangesDto.between(event.scheduleId, event.scheduleVersion, event.before, event.after)
        if (changes.changedFields.isEmpty()) return

        val actor = memberRepository.findById(event.actorId).orElseThrow()
        val payload = ScheduleUpdatedPayload(
            actor = NotificationActorSnapshot(actor.name, actor.hasProfilePhoto(), actor.profilePhotoVersion),
            scheduleVersion = event.scheduleVersion,
            changedFields = changes.changedFields,
        )
        val retainedTags = event.before.tags.map { it.id }.toSet().intersect(event.after.tags.map { it.id }.toSet())
        val recipients = (retainedTags + event.ownerId) - event.actorId
        recipients.forEach { recipientId ->
            if (blockService.isBlockedEitherWay(event.actorId, recipientId) ||
                blockService.isBlockedEitherWay(event.ownerId, recipientId)) return@forEach
            val eventKey = "schedule:${event.scheduleId}:${event.scheduleVersion}:$recipientId"
            if (notificationRepository.existsByEventKey(eventKey)) return@forEach
            val notification = notificationService.createNotification(
                memberId = recipientId,
                type = NotificationType.SCHEDULE_UPDATED,
                actorId = event.actorId,
                referenceType = NotificationReferenceType.SCHEDULE,
                referenceId = event.scheduleId.toString(),
                payload = payload,
            )
            notification.eventKey = eventKey
            eventPublisher.publishEvent(ScheduleUpdateNotificationPersistedEvent(notification.id, payload))
        }
    }
}
