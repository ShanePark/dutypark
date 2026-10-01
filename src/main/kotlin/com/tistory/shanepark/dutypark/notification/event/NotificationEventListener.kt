package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.InquiryAnsweredPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ActorNotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusDonePayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusInProgressPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusTodoPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.push.apns.service.ApnsPushService
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
    private val apnsPushService: ApnsPushService,
    private val blockService: BlockService,
) {
    private val log = logger()

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFriendRequestSent(event: FriendRequestSentEvent) {
        processNotificationEvent(
            eventName = "friend_request_sent",
            eventId = event.requestId,
            memberId = event.toMemberId,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            actorId = event.fromMemberId,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = event.requestId.toString(),
        ) {
            FriendRequestReceivedPayload(
                actor = actorSnapshot(event.fromMemberId)
            )
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFriendRequestAccepted(event: FriendRequestAcceptedEvent) {
        processNotificationEvent(
            eventName = "friend_request_accepted",
            memberId = event.fromMemberId,
            type = NotificationType.FRIEND_REQUEST_ACCEPTED,
            actorId = event.toMemberId,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = null,
        ) {
            FriendRequestAcceptedPayload(
                actor = actorSnapshot(event.toMemberId)
            )
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFamilyRequestSent(event: FamilyRequestSentEvent) {
        processNotificationEvent(
            eventName = "family_request_sent",
            eventId = event.requestId,
            memberId = event.toMemberId,
            type = NotificationType.FAMILY_REQUEST_RECEIVED,
            actorId = event.fromMemberId,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = event.requestId.toString(),
        ) {
            FamilyRequestReceivedPayload(
                actor = actorSnapshot(event.fromMemberId)
            )
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleFamilyRequestAccepted(event: FamilyRequestAcceptedEvent) {
        processNotificationEvent(
            eventName = "family_request_accepted",
            memberId = event.fromMemberId,
            type = NotificationType.FAMILY_REQUEST_ACCEPTED,
            actorId = event.toMemberId,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = null,
        ) {
            FamilyRequestAcceptedPayload(
                actor = actorSnapshot(event.toMemberId)
            )
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleScheduleTagged(event: ScheduleTaggedEvent) {
        processNotificationEvent(
            eventName = "schedule_tagged",
            eventId = event.scheduleId,
            memberId = event.taggedMemberId,
            type = NotificationType.SCHEDULE_TAGGED,
            actorId = event.ownerId,
            referenceType = NotificationReferenceType.SCHEDULE,
            referenceId = event.scheduleId.toString(),
        ) {
            ScheduleTaggedPayload(
                actor = actorSnapshot(event.ownerId),
                scheduleTitle = event.scheduleTitle,
            )
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleTodoTagged(event: TodoTaggedEvent) {
        processNotificationEvent(
            eventName = "todo_tagged",
            eventId = event.todoId,
            memberId = event.taggedMemberId,
            type = NotificationType.TODO_TAGGED,
            actorId = event.ownerId,
            referenceType = NotificationReferenceType.TODO,
            referenceId = event.todoId.toString(),
        ) {
            TodoTaggedPayload(
                actor = actorSnapshot(event.ownerId),
                todoTitle = event.todoTitle,
            )
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleTodoStatusChanged(event: TodoStatusChangedEvent) {
        processNotificationEvent(
            eventName = "todo_status_changed",
            eventId = event.todoId,
            memberId = event.recipientMemberId,
            type = getTodoStatusChangedNotificationType(event.newStatus),
            actorId = event.actorId,
            referenceType = NotificationReferenceType.TODO,
            referenceId = event.todoId.toString(),
        ) {
            getTodoStatusPayload(event.actorId, event.todoTitle, event.newStatus)
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("notificationExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun handleInquiryAnswered(event: InquiryAnsweredEvent) {
        processNotificationEvent(
            eventName = "inquiry_answered",
            eventId = event.inquiryId,
            memberId = event.memberId,
            type = NotificationType.INQUIRY_ANSWERED,
            actorId = null,
            referenceType = NotificationReferenceType.INQUIRY,
            referenceId = event.inquiryId.toString(),
        ) {
            InquiryAnsweredPayload(subject = event.subject)
        }
    }

    private fun processNotificationEvent(
        eventName: String,
        eventId: Any? = null,
        memberId: Long,
        type: NotificationType,
        actorId: Long?,
        referenceType: NotificationReferenceType?,
        referenceId: String?,
        payloadFactory: () -> NotificationPayload,
    ) {
        var payload: NotificationPayload? = null
        var notificationId: Any? = null
        try {
            payload = payloadFactory()
            val actorName = (payload as? ActorNotificationPayload)?.actor?.name
            if (actorId != null && blockService.isBlockedEitherWay(actorId, memberId)) {
                log.info(
                    "Notification skipped for blocked members: {}",
                    auditContext(
                        mapOf(
                            "event" to eventName,
                            "eventId" to eventId,
                            "notificationType" to type,
                            "recipientMemberId" to memberId,
                            "actorMemberId" to actorId,
                            "actorName" to actorName,
                            "referenceType" to referenceType,
                            "referenceId" to referenceId,
                            "reason" to "blocked_members",
                        )
                    ),
                )
                return
            }

            val notification = notificationService.createNotification(
                memberId = memberId,
                type = type,
                actorId = actorId,
                referenceType = referenceType,
                referenceId = referenceId,
                payload = payload,
            )
            notificationId = notification.id
            sendPushNotification(notification, NotificationDto.of(notification, payload))
        } catch (e: Exception) {
            logNotificationFailure(
                eventName = eventName,
                eventId = eventId,
                notificationId = notificationId,
                memberId = memberId,
                type = type,
                actorId = actorId,
                actorName = (payload as? ActorNotificationPayload)?.actor?.name,
                referenceType = referenceType,
                referenceId = referenceId,
                error = e,
            )
        }
    }

    private fun logNotificationFailure(
        eventName: String,
        eventId: Any?,
        notificationId: Any?,
        memberId: Long,
        type: NotificationType,
        actorId: Long?,
        actorName: String?,
        referenceType: NotificationReferenceType?,
        referenceId: String?,
        error: Exception,
    ) {
        val causes = generateSequence(error as Throwable?) { it.cause }.take(5).toList()
        val stackFrames = causes.flatMap { cause ->
            cause.stackTrace.take(8).map { frame ->
                "${frame.className}.${frame.methodName}:${frame.lineNumber}"
            }
        }.take(24)
        log.error(
            "Notification event processing failed: {}",
            auditContext(
                mapOf(
                    "event" to eventName,
                    "eventId" to eventId,
                    "notificationId" to notificationId,
                    "notificationType" to type,
                    "recipientMemberId" to memberId,
                    "actorMemberId" to actorId,
                    "actorName" to actorName,
                    "referenceType" to referenceType,
                    "referenceId" to referenceId,
                    "causeTypes" to causes.map { it.javaClass.simpleName },
                    "stackFrames" to stackFrames,
                )
            ),
        )
    }

    private fun sendPushNotification(notification: Notification, notificationDto: NotificationDto) {
        val memberId = notification.member.id!!
        val unreadCount = notificationRepository.countByMemberIdAndIsReadFalse(memberId).toInt()

        val payload = PushNotificationPayload(
            type = notification.type,
            url = getNotificationUrl(notification),
            notificationId = notification.id.toString(),
            unreadCount = unreadCount,
            notification = notificationDto,
        )
        webPushService.sendToMember(memberId, payload)
        apnsPushService.sendToMember(memberId, payload)
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
            NotificationReferenceType.INQUIRY -> "/support?tab=history"
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
