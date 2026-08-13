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
import java.time.Duration
import java.time.LocalDateTime
import java.util.Base64
import java.util.Date

@Service
class ApnsPushService @Autowired constructor(
    private val apnsInstallationRepository: ApnsInstallationRepository,
    private val objectMapper: ObjectMapper,
    @param:Value("\${dutypark.apns.team-id:}") private val teamId: String,
    @param:Value("\${dutypark.apns.key-id:}") private val keyId: String,
    @param:Value("\${dutypark.apns.private-key:}") private val privateKeyPem: String,
) {
    private val log = logger()
    private val signingKey: PrivateKey? = parsePrivateKey(privateKeyPem)
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
    ) : this(apnsInstallationRepository, objectMapper, teamId, keyId, privateKeyPem) {
        this.httpClient = httpClient
    }

    fun sendToMember(memberId: Long, payload: PushNotificationPayload) {
        val key = signingKey ?: return
        if (teamId.isBlank() || keyId.isBlank()) return

        val installations = apnsInstallationRepository.findAllDeliverableByMemberId(memberId, LocalDateTime.now())
        if (installations.isEmpty()) return

        val authorization = "bearer " + Jwts.builder()
            .header().keyId(keyId).and()
            .issuer(teamId)
            .issuedAt(Date())
            .signWith(key, Jwts.SIG.ES256)
            .compact()
        val body = objectMapper.writeValueAsString(buildPayload(payload))

        installations.forEach { installation ->
            send(installation, authorization, body)
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
                    error != null -> log.warn("Failed to send APNs notification: {}", error.message)
                    response.statusCode() == 410 -> {
                        apnsInstallationRepository.delete(installation)
                        log.info("Removed expired APNs installation")
                    }
                    response.statusCode() !in 200..299 ->
                        log.warn("APNs notification failed with status {}", response.statusCode())
                }
            }
    }

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

    private fun parsePrivateKey(value: String): PrivateKey? {
        if (value.isBlank()) return null
        return try {
            val encoded = value.replace("\\n", "\n")
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .filterNot(Char::isWhitespace)
            KeyFactory.getInstance("EC").generatePrivate(
                PKCS8EncodedKeySpec(Base64.getDecoder().decode(encoded))
            )
        } catch (e: Exception) {
            log.error("APNs private key could not be loaded: {}", e.message)
            null
        }
    }

    private data class LocalizedAlert(
        val key: String,
        val arguments: List<String> = emptyList(),
    )

    companion object {
        private const val TOPIC = "com.tistory.shanepark.dutypark"
        private const val SANDBOX_HOST = "api.sandbox.push.apple.com"
        private const val PRODUCTION_HOST = "api.push.apple.com"
    }
}
