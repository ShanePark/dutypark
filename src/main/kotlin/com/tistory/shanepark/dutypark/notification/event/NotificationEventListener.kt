package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.service.WebPushService
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.event.TransactionPhase
import org.springframework.transaction.event.TransactionalEventListener

@Component
class NotificationEventListener(
    private val notificationService: NotificationService,
    private val notificationRepository: NotificationRepository,
    private val memberRepository: MemberRepository,
    private val webPushService: WebPushService
) {
    private val log = logger()

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFriendRequestSent(event: FriendRequestSentEvent) {
        log.info("Handling FriendRequestSentEvent: from={} to={}", event.fromMemberId, event.toMemberId)
        try {
            val notification = notificationService.createNotification(
                memberId = event.toMemberId,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                actorId = event.fromMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = event.requestId.toString(),
                content = null
            )
            sendPushNotification(notification)
            log.info("Created friend request notification for member {}", event.toMemberId)
        } catch (e: Exception) {
            log.error("Failed to create friend request notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFriendRequestAccepted(event: FriendRequestAcceptedEvent) {
        log.info("Handling FriendRequestAcceptedEvent: from={} to={}", event.fromMemberId, event.toMemberId)
        try {
            val notification = notificationService.createNotification(
                memberId = event.fromMemberId,
                type = NotificationType.FRIEND_REQUEST_ACCEPTED,
                actorId = event.toMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = null,
                content = null
            )
            sendPushNotification(notification)
            log.info("Created friend accepted notification for member {}", event.fromMemberId)
        } catch (e: Exception) {
            log.error("Failed to create friend accepted notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFamilyRequestSent(event: FamilyRequestSentEvent) {
        log.info("Handling FamilyRequestSentEvent: from={} to={}", event.fromMemberId, event.toMemberId)
        try {
            val notification = notificationService.createNotification(
                memberId = event.toMemberId,
                type = NotificationType.FAMILY_REQUEST_RECEIVED,
                actorId = event.fromMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = event.requestId.toString(),
                content = null
            )
            sendPushNotification(notification)
            log.info("Created family request notification for member {}", event.toMemberId)
        } catch (e: Exception) {
            log.error("Failed to create family request notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFamilyRequestAccepted(event: FamilyRequestAcceptedEvent) {
        log.info("Handling FamilyRequestAcceptedEvent: from={} to={}", event.fromMemberId, event.toMemberId)
        try {
            val notification = notificationService.createNotification(
                memberId = event.fromMemberId,
                type = NotificationType.FAMILY_REQUEST_ACCEPTED,
                actorId = event.toMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = null,
                content = null
            )
            sendPushNotification(notification)
            log.info("Created family accepted notification for member {}", event.fromMemberId)
        } catch (e: Exception) {
            log.error("Failed to create family accepted notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleScheduleTagged(event: ScheduleTaggedEvent) {
        log.info("Handling ScheduleTaggedEvent: owner={} tagged={}", event.ownerId, event.taggedMemberId)
        try {
            val notification = notificationService.createNotification(
                memberId = event.taggedMemberId,
                type = NotificationType.SCHEDULE_TAGGED,
                actorId = event.ownerId,
                referenceType = NotificationReferenceType.SCHEDULE,
                referenceId = event.scheduleId.toString(),
                content = event.scheduleTitle
            )
            sendPushNotification(notification)
            log.info("Created schedule tagged notification for member {}", event.taggedMemberId)
        } catch (e: Exception) {
            log.error("Failed to create schedule tagged notification: {}", e.message, e)
        }
    }

    private fun sendPushNotification(notification: Notification) {
        val memberId = notification.member.id!!
        val unreadCount = notificationRepository.countByMemberIdAndIsReadFalse(memberId).toInt()

        val actorName = notification.actorId?.let { actorId ->
            memberRepository.findById(actorId).orElse(null)?.name
        }
        val pushBody = notification.type.generatePushBody(notification.content)

        webPushService.sendToMember(
            memberId = memberId,
            payload = PushNotificationPayload(
                title = actorName,
                body = pushBody,
                url = getNotificationUrl(notification),
                notificationId = notification.id.toString(),
                unreadCount = unreadCount
            )
        )
    }

    private fun getNotificationUrl(notification: Notification): String {
        return when (notification.referenceType) {
            NotificationReferenceType.FRIEND_REQUEST -> "/friends"
            NotificationReferenceType.SCHEDULE -> "/duty/${notification.member.id}"
            NotificationReferenceType.MEMBER -> "/duty/${notification.referenceId}"
            else -> "/"
        }
    }
}
