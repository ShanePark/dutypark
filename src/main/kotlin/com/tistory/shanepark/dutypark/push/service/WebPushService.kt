package com.tistory.shanepark.dutypark.push.service

import tools.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionRequest
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import nl.martijndwars.webpush.Notification
import nl.martijndwars.webpush.PushService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime

@Service
@Transactional
class WebPushService(
    private val refreshTokenRepository: RefreshTokenRepository,
    private val objectMapper: ObjectMapper,
    @Autowired(required = false)
    private val pushService: PushService?
) {
    private val log = logger()

    fun isEnabled(): Boolean = pushService != null

    fun subscribe(refreshToken: RefreshToken, request: PushSubscriptionRequest): Boolean {
        if (!isEnabled()) return false

        refreshTokenRepository.findByPushEndpoint(request.endpoint)?.let { existingToken ->
            if (existingToken.id != refreshToken.id) {
                existingToken.unsubscribePush()
                refreshTokenRepository.saveAndFlush(existingToken)
            }
        }

        refreshToken.subscribePush(
            endpoint = request.endpoint,
            p256dh = request.keys.p256dh,
            auth = request.keys.auth
        )
        refreshTokenRepository.save(refreshToken)
        return true
    }

    fun unsubscribe(refreshToken: RefreshToken): Boolean {
        if (!refreshToken.hasPushSubscription()) return false

        refreshToken.unsubscribePush()
        refreshTokenRepository.save(refreshToken)
        log.info("Push subscription removed for token {}", refreshToken.id)
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

        val payloadJson = try {
            objectMapper.writeValueAsString(payload)
        } catch (e: Exception) {
            log.error("Failed to serialize push payload for member {}: {}", memberId, e.message, e)
            return
        }

        tokens.forEach { token ->
            try {
                if (token.pushEndpoint.isNullOrBlank() || token.pushP256dh.isNullOrBlank() || token.pushAuth.isNullOrBlank()) {
                    log.warn("Push subscription data missing for token {}, removing", token.id)
                    token.unsubscribePush()
                    refreshTokenRepository.save(token)
                    return@forEach
                }
                sendNotification(token, payloadJson)
            } catch (e: Exception) {
                log.error("Failed to send push to token {}: {}", token.id, e.message)
                handleSendError(token, e)
            }
        }
    }

    private fun sendNotification(token: RefreshToken, payloadJson: String) {
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
            log.info("Push subscription expired, removing from token: {}", token.id)
            token.unsubscribePush()
            refreshTokenRepository.save(token)
        } else if (statusCode !in 200..299) {
            log.warn("Push may have failed for token {}: status={}", token.id, statusCode)
        }
    }

    private fun handleSendError(token: RefreshToken, e: Exception) {
        if (e.message?.contains("410") == true || e.message?.contains("expired") == true) {
            token.unsubscribePush()
            refreshTokenRepository.save(token)
        }
    }
}
