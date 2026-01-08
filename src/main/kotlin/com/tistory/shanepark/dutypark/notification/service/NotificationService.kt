package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.dto.NotificationCountDto
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Service
@Transactional
class NotificationService(
    private val notificationRepository: NotificationRepository,
    private val memberRepository: MemberRepository,
    private val friendRequestRepository: FriendRequestRepository
) {

    @Transactional(readOnly = true)
    fun getUnreadNotifications(memberId: Long): List<NotificationDto> {
        val notifications = notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(memberId)
            .take(50)

        return enrichWithActorInfo(notifications)
    }

    @Transactional(readOnly = true)
    fun getNotifications(memberId: Long, pageable: Pageable): Page<NotificationDto> {
        val notificationPage = notificationRepository.findByMemberIdOrderByCreatedDateDesc(memberId, pageable)
        val dtos = enrichWithActorInfo(notificationPage.content)

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

    fun markAsRead(memberId: Long, notificationId: UUID): NotificationDto {
        val notification = notificationRepository.findByMemberIdAndId(memberId, notificationId)
            ?: throw NoSuchElementException("Notification not found")

        notification.isRead = true
        notificationRepository.save(notification)

        val actor = notification.actorId?.let { memberRepository.findById(it).orElse(null) }
        return NotificationDto.of(notification, actor)
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
        content: String?
    ): Notification {
        val member = memberRepository.findById(memberId).orElseThrow {
            NoSuchElementException("Member not found: $memberId")
        }

        val actorName = actorId?.let { id ->
            memberRepository.findById(id).orElse(null)?.name ?: "Unknown"
        } ?: "Unknown"

        val title = type.generateTitle(actorName)

        val notification = Notification(
            member = member,
            type = type,
            title = title,
            content = content,
            referenceType = referenceType,
            referenceId = referenceId,
            actorId = actorId
        )

        return notificationRepository.save(notification)
    }

    private fun enrichWithActorInfo(notifications: List<Notification>): List<NotificationDto> {
        val actorIds = notifications.mapNotNull { it.actorId }.distinct()
        val actorMap = if (actorIds.isNotEmpty()) {
            memberRepository.findAllById(actorIds).associateBy { it.id }
        } else {
            emptyMap()
        }

        return notifications.map { notification ->
            val actor = notification.actorId?.let { actorMap[it] }
            NotificationDto.of(notification, actor)
        }
    }
}
