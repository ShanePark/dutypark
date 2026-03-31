package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.common.config.logger
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
import org.springframework.data.domain.PageImpl
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
        if (pageable.isUnpaged) {
            val notifications = notificationRepository.findAllByMemberIdOrderByCreatedDateDesc(memberId)
            val content = notifications.map { toDto(memberId, it, "getNotifications") }
            return PageImpl(content, pageable, content.size.toLong())
        }

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
    fun getFriendRequestCount(memberId: Long): Int {
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
    }

    fun deleteAllRead(memberId: Long): Int {
        return notificationRepository.deleteByMemberIdAndIsReadTrue(memberId)
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

        return notificationRepository.save(notification)
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
            is NotificationPayloadDecodeResult.Missing -> fallbackPayload(memberId, notification, source, result.reason)
            is NotificationPayloadDecodeResult.Invalid -> fallbackPayload(memberId, notification, source, result.reason)
        }
    }

    private fun fallbackPayload(memberId: Long, notification: Notification, source: String, reason: String): NotificationPayload {
        log.warn(
            "Falling back to generic payload for notification {} of member {} during {} because payload is invalid (type={}, version={}, reason={})",
            notification.id,
            memberId,
            source,
            notification.type,
            notification.payloadVersion,
            reason,
        )
        return UnknownNotificationPayload()
    }
}
