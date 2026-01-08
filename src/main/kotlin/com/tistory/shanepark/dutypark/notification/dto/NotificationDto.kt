package com.tistory.shanepark.dutypark.notification.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import java.time.LocalDateTime
import java.util.*

data class NotificationDto(
    val id: UUID,
    val type: NotificationType,
    val title: String,
    val content: String?,
    val referenceType: NotificationReferenceType?,
    val referenceId: String?,
    val actorId: Long?,
    val actorName: String?,
    val actorHasProfilePhoto: Boolean,
    val actorProfilePhotoVersion: Long,
    val isRead: Boolean,
    val createdAt: LocalDateTime
) {
    companion object {
        fun of(notification: Notification, actor: Member?): NotificationDto {
            return NotificationDto(
                id = notification.id,
                type = notification.type,
                title = notification.title,
                content = notification.content,
                referenceType = notification.referenceType,
                referenceId = notification.referenceId,
                actorId = notification.actorId,
                actorName = actor?.name,
                actorHasProfilePhoto = actor?.hasProfilePhoto() ?: false,
                actorProfilePhotoVersion = actor?.profilePhotoVersion ?: 0,
                isRead = notification.isRead,
                createdAt = notification.createdDate
            )
        }
    }
}
