package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.UnknownNotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.dto.NotificationCountDto
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
@Transactional
class NotificationService(
    private val notificationRepository: NotificationRepository,
    private val memberRepository: MemberRepository,
    private val friendRequestRepository: FriendRequestRepository,
    private val notificationPayloadCodec: NotificationPayloadCodec,
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun getUnreadNotifications(memberId: Long): List<NotificationDto> {
        val notifications = notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(memberId)
        return notifications.take(50)
            .map { toDto(memberId, it, "getUnreadNotifications") }
    }

    @Transactional(readOnly = true)
    fun getNotifications(memberId: Long, pageable: Pageable): Page<NotificationDto> {
        return notificationRepository.findByMemberIdOrderByCreatedDateDesc(memberId, pageable)
            .map { toDto(memberId, it, "getNotifications") }
    }

    @Transactional(readOnly = true)
    fun getUnreadCountSimple(memberId: Long): NotificationCountDto {
        return NotificationCountDto(
            unreadCount = notificationRepository.countByMemberIdAndIsReadFalse(memberId).toInt(),
            totalCount = notificationRepository.countByMemberId(memberId).toInt(),
        )
    }

    @Transactional(readOnly = true)
    fun getPendingRequestCount(memberId: Long): Int {
        return friendRequestRepository.countByToMemberIdAndStatus(memberId, FriendRequestStatus.PENDING).toInt()
    }

    fun markAsRead(memberId: Long, notificationId: UUID): NotificationDto {
        val notification = notificationRepository.findByMemberIdAndId(memberId, notificationId)
            ?: throw NoSuchElementException("Notification not found")

        notification.isRead = true
        notificationRepository.save(notification)

        return toDto(memberId, notification, "markAsRead")
    }

    fun markAllAsRead(memberId: Long): Int {
        val notifications = notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(memberId)
        notifications.forEach { it.isRead = true }
        notificationRepository.saveAll(notifications)
        return notifications.size
    }

    fun deleteNotification(memberId: Long, notificationId: UUID) {
        val notification = notificationRepository.findByMemberIdAndId(memberId, notificationId)
            ?: throw NoSuchElementException("Notification not found")

        notificationRepository.delete(notification)
        log.auditEventAfterCommit(
            "notification_deleted", null,
            target = mapOf("memberId" to memberId, "notificationId" to notificationId),
            details = mapOf("notificationType" to notification.type),
        )
    }

    fun deleteAllRead(memberId: Long): Int {
        val deletedCount = notificationRepository.deleteByMemberIdAndIsReadTrue(memberId)
        if (deletedCount > 0) {
            log.auditEventAfterCommit(
                "read_notifications_deleted", null, mapOf("memberId" to memberId),
                mapOf("deletedCount" to deletedCount),
            )
        }
        return deletedCount
    }

    fun createNotification(
        memberId: Long,
        type: NotificationType,
        actorId: Long?,
        referenceType: NotificationReferenceType?,
        referenceId: String?,
        payload: NotificationPayload
    ): Notification {
        val member = memberRepository.findById(memberId).orElseThrow {
            NoSuchElementException("Member not found: $memberId")
        }
        notificationPayloadCodec.ensureCompatible(type, payload)

        val notification = Notification(
            member = member,
            type = type,
            referenceType = referenceType,
            referenceId = referenceId,
            actorId = actorId,
            payloadJson = notificationPayloadCodec.serialize(payload),
            payloadVersion = payload.version
        )

        val saved = notificationRepository.save(notification)
        log.auditEventAfterCommit(
            "notification_created", null,
            target = mapOf("memberId" to memberId, "notificationId" to saved.id),
            details = mapOf("actorMemberId" to actorId, "notificationType" to type,
                "referenceType" to referenceType, "referenceId" to referenceId),
        )
        return saved
    }

    private fun toDto(memberId: Long, notification: Notification, source: String): NotificationDto {
        return NotificationDto.of(
            notification = notification,
            payload = materializePayload(memberId, notification, source),
        )
    }

    private fun materializePayload(memberId: Long, notification: Notification, source: String): NotificationPayload {
        return when (val result = notificationPayloadCodec.safeDeserialize(
            notification.type,
            notification.payloadVersion,
            notification.payloadJson,
        )) {
            is NotificationPayloadDecodeResult.Success -> result.payload
            is NotificationPayloadDecodeResult.Missing -> fallbackPayload(
                memberId,
                notification,
                source,
                decodeStatus = "MISSING",
            )
            is NotificationPayloadDecodeResult.Invalid -> fallbackPayload(
                memberId,
                notification,
                source,
                decodeStatus = "INVALID",
            )
        }
    }

    private fun fallbackPayload(
        memberId: Long,
        notification: Notification,
        source: String,
        decodeStatus: String,
    ): NotificationPayload {
        log.warn(
            "Notification payload fallback: {}",
            auditContext(
                mapOf(
                    "event" to "notification_payload_fallback",
                    "notificationId" to notification.id,
                    "memberId" to memberId,
                    "actorMemberId" to notification.actorId,
                    "referenceType" to notification.referenceType,
                    "referenceId" to notification.referenceId,
                    "source" to source,
                    "notificationType" to notification.type,
                    "payloadVersion" to notification.payloadVersion,
                    "decodeStatus" to decodeStatus,
                )
            ),
        )
        return UnknownNotificationPayload()
    }
}
