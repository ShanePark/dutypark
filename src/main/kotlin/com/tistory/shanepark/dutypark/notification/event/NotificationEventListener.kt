package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusDonePayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusInProgressPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusTodoPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.service.WebPushService
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
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
    private val webPushService: WebPushService,
) {
    private val log = logger()

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFriendRequestSent(event: FriendRequestSentEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.toMemberId,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                actorId = event.fromMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = event.requestId.toString(),
                payload = FriendRequestReceivedPayload(
                    actor = actorSnapshot(event.fromMemberId)
                )
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create friend request notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFriendRequestAccepted(event: FriendRequestAcceptedEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.fromMemberId,
                type = NotificationType.FRIEND_REQUEST_ACCEPTED,
                actorId = event.toMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = null,
                payload = FriendRequestAcceptedPayload(
                    actor = actorSnapshot(event.toMemberId)
                )
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create friend accepted notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFamilyRequestSent(event: FamilyRequestSentEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.toMemberId,
                type = NotificationType.FAMILY_REQUEST_RECEIVED,
                actorId = event.fromMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = event.requestId.toString(),
                payload = FamilyRequestReceivedPayload(
                    actor = actorSnapshot(event.fromMemberId)
                )
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create family request notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFamilyRequestAccepted(event: FamilyRequestAcceptedEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.fromMemberId,
                type = NotificationType.FAMILY_REQUEST_ACCEPTED,
                actorId = event.toMemberId,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = null,
                payload = FamilyRequestAcceptedPayload(
                    actor = actorSnapshot(event.toMemberId)
                )
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create family accepted notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleScheduleTagged(event: ScheduleTaggedEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.taggedMemberId,
                type = NotificationType.SCHEDULE_TAGGED,
                actorId = event.ownerId,
                referenceType = NotificationReferenceType.SCHEDULE,
                referenceId = event.scheduleId.toString(),
                payload = ScheduleTaggedPayload(
                    actor = actorSnapshot(event.ownerId),
                    scheduleTitle = event.scheduleTitle
                )
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create schedule tagged notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleTodoTagged(event: TodoTaggedEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.taggedMemberId,
                type = NotificationType.TODO_TAGGED,
                actorId = event.ownerId,
                referenceType = NotificationReferenceType.TODO,
                referenceId = event.todoId.toString(),
                payload = TodoTaggedPayload(
                    actor = actorSnapshot(event.ownerId),
                    todoTitle = event.todoTitle
                )
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create todo tagged notification: {}", e.message, e)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleTodoStatusChanged(event: TodoStatusChangedEvent) {
        try {
            val notification = notificationService.createNotification(
                memberId = event.recipientMemberId,
                type = getTodoStatusChangedNotificationType(event.newStatus),
                actorId = event.actorId,
                referenceType = NotificationReferenceType.TODO,
                referenceId = event.todoId.toString(),
                payload = getTodoStatusPayload(event.actorId, event.todoTitle, event.newStatus)
            )
            sendPushNotification(notification)
        } catch (e: Exception) {
            log.error("Failed to create todo status changed notification: {}", e.message, e)
        }
    }

    private fun sendPushNotification(notification: Notification) {
        val memberId = notification.member.id!!
        val unreadCount = notificationRepository.countByMemberIdAndIsReadFalse(memberId).toInt()

        webPushService.sendToMember(
            memberId = memberId,
            payload = PushNotificationPayload(
                type = notification.type,
                url = getNotificationUrl(notification),
                notificationId = notification.id.toString(),
                unreadCount = unreadCount
            )
        )
    }

    private fun actorSnapshot(actorId: Long?): NotificationActorSnapshot {
        val actor = actorId?.let { memberRepository.findById(it).orElse(null) }
        return NotificationActorSnapshot(
            name = actor?.name,
            hasProfilePhoto = actor?.hasProfilePhoto() ?: false,
            profilePhotoVersion = actor?.profilePhotoVersion ?: 0
        )
    }

    private fun getTodoStatusPayload(actorId: Long, todoTitle: String, status: TodoStatus): NotificationPayload {
        val actor = actorSnapshot(actorId)
        return when (status) {
            TodoStatus.TODO -> TodoStatusTodoPayload(actor = actor, todoTitle = todoTitle)
            TodoStatus.IN_PROGRESS -> TodoStatusInProgressPayload(actor = actor, todoTitle = todoTitle)
            TodoStatus.DONE -> TodoStatusDonePayload(actor = actor, todoTitle = todoTitle)
        }
    }

    private fun getNotificationUrl(notification: Notification): String {
        return when (notification.referenceType) {
            NotificationReferenceType.FRIEND_REQUEST -> "/friends"
            NotificationReferenceType.SCHEDULE -> "/duty/${notification.member.id}"
            NotificationReferenceType.TODO -> "/todo"
            NotificationReferenceType.MEMBER -> "/duty/${notification.referenceId}"
            else -> "/"
        }
    }

    private fun getTodoStatusChangedNotificationType(status: TodoStatus): NotificationType {
        return when (status) {
            TodoStatus.TODO -> NotificationType.TODO_STATUS_TODO
            TodoStatus.IN_PROGRESS -> NotificationType.TODO_STATUS_IN_PROGRESS
            TodoStatus.DONE -> NotificationType.TODO_STATUS_DONE
        }
    }
}
