package com.tistory.shanepark.dutypark.push.dto

import com.fasterxml.jackson.annotation.JsonInclude
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank

data class PushSubscriptionRequest(
    @field:NotBlank
    val endpoint: String,
    @field:Valid
    val keys: PushSubscriptionKeys
)

data class PushSubscriptionKeys(
    @field:NotBlank
    val p256dh: String,
    @field:NotBlank
    val auth: String
)

@JsonInclude(JsonInclude.Include.NON_NULL)
data class PushNotificationPayload(
    val type: NotificationType,
    val icon: String = "/android-chrome-192x192-v20260517b.png",
    val badge: String = "/android-chrome-192x192-v20260517b.png",
    val url: String? = null,
    val tag: String? = null,
    val notificationId: String? = null,
    val unreadCount: Int? = null,
    val notification: NotificationDto? = null,
)
