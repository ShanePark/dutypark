package com.tistory.shanepark.dutypark.push.apns.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.ActorNotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusDonePayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusInProgressPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusTodoPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoTaggedPayload
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import io.jsonwebtoken.Jwts
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import tools.jackson.databind.ObjectMapper
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.KeyFactory
import java.security.PrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.LocalDateTime
import java.util.Base64
import java.util.Date
import java.util.UUID

@Service
class ApnsPushService @Autowired constructor(
    private val apnsInstallationRepository: ApnsInstallationRepository,
    private val objectMapper: ObjectMapper,
    @param:Value("\${dutypark.apns.team-id:}") private val teamId: String,
    @param:Value("\${dutypark.apns.key-id:}") keyId: String,
    @param:Value("\${dutypark.apns.private-key:}") privateKeyPem: String,
) {
    private val log = logger()
    private val credentials = credentials(keyId, privateKeyPem)
    private var clock: Clock = Clock.systemUTC()
    private var httpClient: HttpClient = HttpClient.newBuilder()
        .version(HttpClient.Version.HTTP_2)
        .connectTimeout(Duration.ofSeconds(10))
        .build()

    internal constructor(
        apnsInstallationRepository: ApnsInstallationRepository,
        objectMapper: ObjectMapper,
        teamId: String,
        keyId: String,
        privateKeyPem: String,
        httpClient: HttpClient,
        clock: Clock = Clock.systemUTC(),
    ) : this(
        apnsInstallationRepository,
        objectMapper,
        teamId,
        keyId,
        privateKeyPem,
    ) {
        this.httpClient = httpClient
        this.clock = clock
    }

    fun sendToMember(memberId: Long, payload: PushNotificationPayload) {
        val credentials = credentials ?: return
        if (teamId.isBlank()) return

        val installations = apnsInstallationRepository.findAllDeliverableByMemberId(memberId, LocalDateTime.now())
        if (installations.isEmpty()) return

        val body = objectMapper.writeValueAsString(buildPayload(payload))

        installations.forEach { installation ->
            send(installation, credentials.authorization(clock.instant()), body)
        }
    }

    private fun send(installation: ApnsInstallation, authorization: String, body: String) {
        val host = if (installation.sandbox) SANDBOX_HOST else PRODUCTION_HOST
        val request = HttpRequest.newBuilder()
            .uri(URI.create("https://$host/3/device/${installation.deviceToken}"))
            .timeout(Duration.ofSeconds(10))
            .header("authorization", authorization)
            .header("apns-topic", TOPIC)
            .header("apns-push-type", "alert")
            .header("apns-priority", "10")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()

        httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
            .whenComplete { response, error ->
                when {
                    error != null -> log.warn("Failed to send APNs notification: {}", error.javaClass.simpleName)
                    response.statusCode() == 410 -> {
                        apnsInstallationRepository.delete(installation)
                        log.info(
                            "Removed expired APNs installation: status={}, reason={}, apnsId={}",
                            response.statusCode(),
                            safeReason(response),
                            safeApnsId(response),
                        )
                    }
                    response.statusCode() !in 200..299 ->
                        log.warn(
                            "APNs notification failed: status={}, reason={}, apnsId={}",
                            response.statusCode(),
                            safeReason(response),
                            safeApnsId(response),
                        )
                }
            }
    }

    private fun safeReason(response: HttpResponse<String>): String = runCatching {
        objectMapper.readTree(response.body()).get("reason")?.asText()
            ?.takeIf(APNS_REASONS::contains)
    }.getOrNull() ?: UNKNOWN_RESPONSE_VALUE

    private fun safeApnsId(response: HttpResponse<String>): String = runCatching {
        response.headers().firstValue("apns-id").orElse(null)
            ?.let(UUID::fromString)
            ?.toString()
    }.getOrNull() ?: UNKNOWN_RESPONSE_VALUE

    internal fun buildPayload(payload: PushNotificationPayload): Map<String, Any> {
        val localized = localizedAlert(payload)
        val alert = linkedMapOf<String, Any>("loc-key" to localized.key)
        if (localized.arguments.isNotEmpty()) {
            alert["loc-args"] = localized.arguments
        }

        val aps = linkedMapOf<String, Any>(
            "alert" to alert,
            "sound" to "default",
        )
        payload.unreadCount?.let { aps["badge"] = it }

        return linkedMapOf<String, Any>(
            "aps" to aps,
            "type" to payload.type.name,
        ).apply {
            payload.notificationId?.let { put("notificationId", it) }
            payload.url?.let { put("url", it) }
        }
    }

    private fun localizedAlert(payload: PushNotificationPayload): LocalizedAlert {
        val notificationPayload = payload.notification?.payload
        val actor = (notificationPayload as? ActorNotificationPayload)
            ?.actor?.name?.trim()?.takeIf(String::isNotEmpty)

        return when (payload.type) {
            NotificationType.FRIEND_REQUEST_RECEIVED -> actorAlert(actor, "friendRequestReceived")
            NotificationType.FRIEND_REQUEST_ACCEPTED -> actorAlert(actor, "friendRequestAccepted")
            NotificationType.FAMILY_REQUEST_RECEIVED -> actorAlert(actor, "familyRequestReceived")
            NotificationType.FAMILY_REQUEST_ACCEPTED -> actorAlert(actor, "familyRequestAccepted")
            NotificationType.SCHEDULE_TAGGED -> titledAlert(
                actor,
                (notificationPayload as? ScheduleTaggedPayload)?.scheduleTitle.orEmpty(),
                "scheduleTagged",
            )
            NotificationType.TODO_TAGGED -> titledAlert(
                actor,
                (notificationPayload as? TodoTaggedPayload)?.todoTitle.orEmpty(),
                "todoTagged",
            )
            NotificationType.TODO_STATUS_TODO -> titledAlert(
                actor,
                (notificationPayload as? TodoStatusTodoPayload)?.todoTitle.orEmpty(),
                "todoStatusTodo",
            )
            NotificationType.TODO_STATUS_IN_PROGRESS -> titledAlert(
                actor,
                (notificationPayload as? TodoStatusInProgressPayload)?.todoTitle.orEmpty(),
                "todoStatusInProgress",
            )
            NotificationType.TODO_STATUS_DONE -> titledAlert(
                actor,
                (notificationPayload as? TodoStatusDonePayload)?.todoTitle.orEmpty(),
                "todoStatusDone",
            )
        }
    }

    private fun actorAlert(actor: String?, name: String): LocalizedAlert = if (actor == null) {
        LocalizedAlert("notifications.items.${name}Fallback")
    } else {
        LocalizedAlert("notifications.items.$name", listOf(actor))
    }

    private fun titledAlert(actor: String?, title: String, name: String): LocalizedAlert = if (actor == null) {
        LocalizedAlert("notifications.items.${name}Fallback", listOf(title))
    } else {
        LocalizedAlert("notifications.items.$name", listOf(actor, title))
    }

    private fun credentials(keyId: String, privateKeyPem: String): ProviderCredentials? {
        if (keyId.isBlank() || privateKeyPem.isBlank()) return null
        val signingKey = parsePrivateKey(privateKeyPem) ?: return null
        return ProviderCredentials(keyId, signingKey)
    }

    private fun parsePrivateKey(value: String): PrivateKey? {
        return try {
            val encoded = value.replace("\\n", "\n")
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .filterNot(Char::isWhitespace)
            KeyFactory.getInstance("EC").generatePrivate(
                PKCS8EncodedKeySpec(Base64.getDecoder().decode(encoded))
            )
        } catch (e: Exception) {
            log.error("APNs private key could not be loaded: {}", e.javaClass.simpleName)
            null
        }
    }

    private inner class ProviderCredentials(
        private val keyId: String,
        private val signingKey: PrivateKey,
    ) {
        @Volatile
        private var cachedToken: CachedProviderToken? = null

        fun authorization(now: Instant): String {
            val current = cachedToken
            if (current != null && now.isBefore(current.refreshAt)) return current.authorization

            return synchronized(this) {
                val synchronizedCurrent = cachedToken
                if (synchronizedCurrent != null && now.isBefore(synchronizedCurrent.refreshAt)) {
                    synchronizedCurrent.authorization
                } else {
                    val authorization = "bearer " + Jwts.builder()
                        .header().keyId(keyId).and()
                        .issuer(teamId)
                        .issuedAt(Date.from(now))
                        .signWith(signingKey, Jwts.SIG.ES256)
                        .compact()
                    cachedToken = CachedProviderToken(authorization, now.plus(PROVIDER_TOKEN_REFRESH_INTERVAL))
                    authorization
                }
            }
        }
    }

    private data class CachedProviderToken(
        val authorization: String,
        val refreshAt: Instant,
    )

    private data class LocalizedAlert(
        val key: String,
        val arguments: List<String> = emptyList(),
    )

    companion object {
        private const val TOPIC = "io.github.shanepark.dutypark"
        private const val SANDBOX_HOST = "api.sandbox.push.apple.com"
        private const val PRODUCTION_HOST = "api.push.apple.com"
        private const val UNKNOWN_RESPONSE_VALUE = "unknown"
        private val PROVIDER_TOKEN_REFRESH_INTERVAL: Duration = Duration.ofMinutes(50)
        private val APNS_REASONS = setOf(
            "BadCollapseId",
            "BadDeviceToken",
            "BadEnvironmentKeyIdInToken",
            "BadExpirationDate",
            "BadMessageId",
            "BadPriority",
            "BadTopic",
            "DeviceTokenNotForTopic",
            "DuplicateHeaders",
            "IdleTimeout",
            "InvalidPushType",
            "MissingDeviceToken",
            "MissingTopic",
            "PayloadEmpty",
            "TopicDisallowed",
            "BadCertificate",
            "BadCertificateEnvironment",
            "ExpiredProviderToken",
            "Forbidden",
            "InvalidProviderToken",
            "MissingProviderToken",
            "UnrelatedKeyIdInToken",
            "BadPath",
            "MethodNotAllowed",
            "ExpiredToken",
            "Unregistered",
            "PayloadTooLarge",
            "TooManyProviderTokenUpdates",
            "TooManyRequests",
            "InternalServerError",
            "ServiceUnavailable",
            "Shutdown",
        )
    }
}
