package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusDonePayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusInProgressPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusTodoPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoTaggedPayload
import org.springframework.stereotype.Component
import tools.jackson.databind.ObjectMapper
import tools.jackson.databind.node.ObjectNode

sealed interface NotificationPayloadDecodeResult {
    data class Success(val payload: NotificationPayload) : NotificationPayloadDecodeResult

    data class Missing(val reason: String) : NotificationPayloadDecodeResult

    data class Invalid(val reason: String) : NotificationPayloadDecodeResult
}

@Component
class NotificationPayloadCodec(
    private val objectMapper: ObjectMapper,
) {
    fun serialize(payload: NotificationPayload): String {
        return objectMapper.writeValueAsString(payload)
    }

    fun ensureCompatible(type: NotificationType, payload: NotificationPayload) {
        val expectedClass = payloadClass(type, payload.version)
        require(expectedClass.isInstance(payload)) {
            "Notification payload type mismatch for $type version ${payload.version}: expected ${expectedClass.simpleName} but got ${payload::class.java.simpleName}"
        }
    }

    fun safeDeserialize(
        type: NotificationType,
        payloadVersion: Int?,
        payloadJson: String?,
    ): NotificationPayloadDecodeResult {
        if (payloadJson.isNullOrBlank()) {
            return NotificationPayloadDecodeResult.Missing("Notification payload JSON is blank")
        }

        val normalizedPayloadJson = normalize(payloadJson)
        val version = resolveVersion(normalizedPayloadJson, payloadVersion)
        val payloadClass = runCatching { payloadClass(type, version) }
            .getOrElse { return NotificationPayloadDecodeResult.Invalid(it.message ?: "Unsupported notification payload") }

        return runCatching { objectMapper.readValue(normalizedPayloadJson, payloadClass) }
            .fold(
                onSuccess = { NotificationPayloadDecodeResult.Success(it) },
                onFailure = {
                    NotificationPayloadDecodeResult.Invalid(
                        it.message ?: "Failed to decode notification payload"
                    )
                },
            )
    }

    fun deserialize(type: NotificationType, payloadVersion: Int?, payloadJson: String?): NotificationPayload? {
        return when (val result = safeDeserialize(type, payloadVersion, payloadJson)) {
            is NotificationPayloadDecodeResult.Success -> result.payload
            is NotificationPayloadDecodeResult.Missing -> null
            is NotificationPayloadDecodeResult.Invalid -> throw IllegalArgumentException(result.reason)
        }
    }

    @Suppress("LongMethod")
    private fun payloadClass(type: NotificationType, version: Int): Class<out NotificationPayload> {
        return when (version) {
            1 -> when (type) {
                NotificationType.FRIEND_REQUEST_RECEIVED -> FriendRequestReceivedPayload::class.java
                NotificationType.FRIEND_REQUEST_ACCEPTED -> FriendRequestAcceptedPayload::class.java
                NotificationType.FAMILY_REQUEST_RECEIVED -> FamilyRequestReceivedPayload::class.java
                NotificationType.FAMILY_REQUEST_ACCEPTED -> FamilyRequestAcceptedPayload::class.java
                NotificationType.SCHEDULE_TAGGED -> ScheduleTaggedPayload::class.java
                NotificationType.TODO_TAGGED -> TodoTaggedPayload::class.java
                NotificationType.TODO_STATUS_TODO -> TodoStatusTodoPayload::class.java
                NotificationType.TODO_STATUS_IN_PROGRESS -> TodoStatusInProgressPayload::class.java
                NotificationType.TODO_STATUS_DONE -> TodoStatusDonePayload::class.java
            }

            else -> throw IllegalArgumentException("Unsupported notification payload version $version for $type")
        }
    }

    private fun resolveVersion(payloadJson: String, payloadVersion: Int?): Int {
        if (payloadVersion != null && payloadVersion > 0) {
            return payloadVersion
        }

        val version = runCatching { objectMapper.readTree(payloadJson) as? ObjectNode }
            .map { it?.path("version")?.takeIf { node -> node.isInt }?.asInt() }
            .getOrNull()

        return version ?: 1
    }

    private fun normalize(payloadJson: String): String {
        val trimmed = payloadJson.trim()

        if (trimmed.length >= 2 && trimmed.first() == '"' && trimmed.last() == '"') {
            return trimmed.substring(1, trimmed.length - 1)
                .replace("\\\"", "\"")
                .replace("\\n", "\n")
                .replace("\\r", "\r")
                .replace("\\t", "\t")
                .replace("\\\\", "\\")
        }

        runCatching { objectMapper.readValue(trimmed, String::class.java) }
            .getOrNull()
            ?.takeIf { it.trimStart().startsWith("{") }
            ?.let { return it }

        return runCatching { objectMapper.readTree(trimmed) }
            .map { node ->
                when {
                    node.isTextual -> node.asText()
                    else -> trimmed
                }
            }
            .getOrDefault(trimmed)
    }
}
