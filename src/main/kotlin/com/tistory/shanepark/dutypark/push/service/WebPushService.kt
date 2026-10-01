package com.tistory.shanepark.dutypark.push.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.notification.domain.payload.ActorNotificationPayload
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionRequest
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import nl.martijndwars.webpush.Notification
import nl.martijndwars.webpush.PushService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import tools.jackson.databind.ObjectMapper
import java.time.LocalDateTime

@Service
@Transactional
class WebPushService(
    private val refreshTokenRepository: RefreshTokenRepository,
    private val objectMapper: ObjectMapper,
    private val pushService: PushService?,
) {
    private val log = logger()

    fun isEnabled(): Boolean = pushService != null

    fun subscribe(refreshToken: RefreshToken, request: PushSubscriptionRequest, actor: AuditActor? = null): Boolean {
        if (!isEnabled()) return false

        val subscriptionChanged = refreshToken.pushEndpoint != request.endpoint ||
            refreshToken.pushP256dh != request.keys.p256dh || refreshToken.pushAuth != request.keys.auth
        var reassignedFromRefreshTokenId: Long? = null
        refreshTokenRepository.findByPushEndpoint(request.endpoint)?.let { existingToken ->
            if (existingToken.id != refreshToken.id) {
                reassignedFromRefreshTokenId = existingToken.id
                existingToken.unsubscribePush()
                refreshTokenRepository.saveAndFlush(existingToken)
            }
        }

        refreshToken.subscribePush(
            endpoint = request.endpoint,
            p256dh = request.keys.p256dh,
            auth = request.keys.auth,
        )
        refreshTokenRepository.save(refreshToken)
        if (subscriptionChanged || reassignedFromRefreshTokenId != null) {
            log.auditEventAfterCommit(
                event = "web_push_subscription_registered",
                actor = actor,
                target = mapOf("memberId" to refreshToken.member.id, "refreshTokenId" to refreshToken.id),
                details = mapOf("reassignedFromRefreshTokenId" to reassignedFromRefreshTokenId),
            )
        }
        return true
    }

    fun unsubscribe(refreshToken: RefreshToken, actor: AuditActor? = null): Boolean {
        if (!refreshToken.hasPushSubscription()) return false

        refreshToken.unsubscribePush()
        refreshTokenRepository.save(refreshToken)
        log.auditEventAfterCommit(
            event = "web_push_subscription_removed",
            actor = actor ?: refreshToken.member.toAuditActor(),
            target = mapOf("refreshTokenId" to refreshToken.id),
        )
        return true
    }

    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    fun sendToMember(memberId: Long, payload: PushNotificationPayload) {
        if (!isEnabled()) return

        val tokens = refreshTokenRepository
            .findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(memberId, LocalDateTime.now())
        if (tokens.isEmpty()) {
            return
        }

        tokens.forEach { token ->
            try {
                if (token.pushEndpoint.isNullOrBlank() || token.pushP256dh.isNullOrBlank() || token.pushAuth.isNullOrBlank()) {
                    token.unsubscribePush()
                    refreshTokenRepository.save(token)
                    log.warn(
                        "Incomplete Web Push subscription removed: {}",
                        auditContext(pushContext("web_push_subscription_removed_incomplete", memberId, token, payload)),
                    )
                    return@forEach
                }
                val payloadJson = serializePayload(memberId, token, payload) ?: return@forEach
                sendNotification(token, memberId, payload, payloadJson)
            } catch (e: Exception) {
                log.error(
                    "Web Push delivery failed: {}",
                    auditContext(pushContext("web_push_delivery_failed", memberId, token, payload) + safeFailureContext(e)),
                )
                handleSendError(token, e)
            }
        }
    }

    private fun serializePayload(memberId: Long, token: RefreshToken, payload: PushNotificationPayload): String? {
        return try {
            objectMapper.writeValueAsString(payload)
        } catch (e: Exception) {
            log.error(
                "Web Push payload serialization failed: {}",
                auditContext(pushContext("web_push_payload_serialization_failed", memberId, token, payload) + safeFailureContext(e)),
            )
            null
        }
    }

    private fun sendNotification(
        token: RefreshToken,
        memberId: Long,
        payload: PushNotificationPayload,
        payloadJson: String,
    ) {
        val notification = Notification(
            token.pushEndpoint,
            token.pushP256dh,
            token.pushAuth,
            payloadJson.toByteArray()
        )

        val response = pushService?.send(notification)
            ?: throw IllegalStateException("Push service is not available")

        val statusCode = response.statusLine.statusCode

        if (statusCode in listOf(404, 410)) {
            token.unsubscribePush()
            refreshTokenRepository.save(token)
            log.info(
                "Expired Web Push subscription removed: {}",
                auditContext(pushContext("web_push_subscription_expired", memberId, token, payload) + mapOf("status" to statusCode)),
            )
        } else if (statusCode !in 200..299) {
            log.warn(
                "Web Push provider returned a failure status: {}",
                auditContext(pushContext("web_push_provider_failure", memberId, token, payload) + mapOf("status" to statusCode)),
            )
        }
    }

    private fun handleSendError(token: RefreshToken, e: Exception) {
        if (e.message?.contains("410") == true || e.message?.contains("expired") == true) {
            token.unsubscribePush()
            refreshTokenRepository.save(token)
        }
    }

    private fun pushContext(
        event: String,
        memberId: Long,
        token: RefreshToken,
        payload: PushNotificationPayload?,
    ): Map<String, Any?> {
        val actorPayload = payload?.notification?.payload as? ActorNotificationPayload
        return linkedMapOf(
            "event" to event,
            "memberId" to memberId,
            "refreshTokenId" to token.id,
            "notificationId" to (payload?.notificationId ?: payload?.notification?.id),
            "notificationType" to payload?.type,
            "actorMemberId" to payload?.notification?.actorId,
            "actorName" to actorPayload?.actor?.name,
        )
    }

    private fun safeFailureContext(error: Throwable): Map<String, Any?> {
        val causes = generateSequence(error) { it.cause }.take(5).toList()
        val stackFrames = causes.flatMap { cause ->
            cause.stackTrace.take(8).map { frame ->
                "${frame.className}.${frame.methodName}:${frame.lineNumber}"
            }
        }.take(24)
        return mapOf(
            "causeTypes" to causes.map { it.javaClass.simpleName },
            "stackFrames" to stackFrames,
        )
    }
}
