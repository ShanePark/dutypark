package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
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
            .take(50)

        return notifications.mapNotNull { toDtoOrNull(memberId, it, "getUnreadNotifications") }
    }

    @Transactional(readOnly = true)
    fun getNotifications(memberId: Long, pageable: Pageable): Page<NotificationDto> {
        val notificationPage = notificationRepository.findByMemberIdOrderByCreatedDateDesc(memberId, pageable)
        val dtos = notificationPage.content.mapNotNull { toDtoOrNull(memberId, it, "getNotifications") }

        return PageImpl(dtos, pageable, notificationPage.totalElements)
    }

    @Transactional(readOnly = true)
    fun getUnreadCountSimple(memberId: Long): NotificationCountDto {
        val unreadCount = notificationRepository.countByMemberIdAndIsReadFalse(memberId)
        val totalCount = notificationRepository.countByMemberId(memberId)

        return NotificationCountDto(
            unreadCount = unreadCount.toInt(),
            totalCount = totalCount.toInt()
        )
    }

    @Transactional(readOnly = true)
    fun getFriendRequestCount(memberId: Long): Int {
        return friendRequestRepository.countByToMemberIdAndStatus(memberId, FriendRequestStatus.PENDING).toInt()
    }

    @Transactional(noRollbackFor = [BadRequestException::class])
    fun markAsRead(memberId: Long, notificationId: UUID): NotificationDto {
        val notification = notificationRepository.findByMemberIdAndId(memberId, notificationId)
            ?: throw NoSuchElementException("Notification not found")

        notification.isRead = true
        notificationRepository.save(notification)

        return toDtoOrThrow(memberId, notification)
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

    private fun toDtoOrNull(memberId: Long, notification: Notification, source: String): NotificationDto? {
        return when (val result = notificationPayloadCodec.safeDeserialize(
            notification.type,
            notification.payloadVersion,
            notification.payloadJson,
        )) {
            is NotificationPayloadDecodeResult.Success -> NotificationDto.of(notification, result.payload)
            is NotificationPayloadDecodeResult.Missing -> {
                logInvalidPayload(memberId, notification, source, result.reason)
                null
            }

            is NotificationPayloadDecodeResult.Invalid -> {
                logInvalidPayload(memberId, notification, source, result.reason)
                null
            }
        }
    }

    private fun toDtoOrThrow(memberId: Long, notification: Notification): NotificationDto {
        return when (val result = notificationPayloadCodec.safeDeserialize(
            notification.type,
            notification.payloadVersion,
            notification.payloadJson,
        )) {
            is NotificationPayloadDecodeResult.Success -> NotificationDto.of(notification, result.payload)
            is NotificationPayloadDecodeResult.Missing -> throwInvalidPayload(memberId, notification, "markAsRead", result.reason)
            is NotificationPayloadDecodeResult.Invalid -> throwInvalidPayload(memberId, notification, "markAsRead", result.reason)
        }
    }

    private fun logInvalidPayload(memberId: Long, notification: Notification, source: String, reason: String) {
        log.warn(
            "Skipping notification {} for member {} during {} because payload is invalid (type={}, version={}, reason={})",
            notification.id,
            memberId,
            source,
            notification.type,
            notification.payloadVersion,
            reason,
        )
    }

    private fun throwInvalidPayload(memberId: Long, notification: Notification, source: String, reason: String): Nothing {
        log.warn(
            "Notification {} for member {} could not be materialized during {} because payload is invalid (type={}, version={}, reason={})",
            notification.id,
            memberId,
            source,
            notification.type,
            notification.payloadVersion,
            reason,
        )
        throw BadRequestException(INVALID_NOTIFICATION_PAYLOAD_CODE)
    }

    companion object {
        private const val INVALID_NOTIFICATION_PAYLOAD_CODE = "notification.payload.invalid"
    }
}
