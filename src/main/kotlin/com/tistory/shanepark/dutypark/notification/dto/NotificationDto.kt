package com.tistory.shanepark.dutypark.notification.dto

import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import java.time.LocalDateTime
import java.util.*

data class NotificationDto(
    val id: UUID,
    val type: NotificationType,
    val referenceType: NotificationReferenceType?,
    val referenceId: String?,
    val actorId: Long?,
    val payload: NotificationPayload,
    val isRead: Boolean,
    val createdAt: LocalDateTime
) {
    companion object {
        fun of(notification: Notification, payload: NotificationPayload): NotificationDto {
            return NotificationDto(
                id = notification.id,
                type = notification.type,
                referenceType = notification.referenceType,
                referenceId = notification.referenceId,
                actorId = notification.actorId,
                payload = payload,
                isRead = notification.isRead,
                createdAt = notification.createdDate
            )
        }
    }
}
