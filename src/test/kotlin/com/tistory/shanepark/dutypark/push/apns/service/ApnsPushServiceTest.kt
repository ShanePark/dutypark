package com.tistory.shanepark.dutypark.push.apns.service

import com.tistory.shanepark.dutypark.TestUtils
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.dto.NotificationDto
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.KeyPairGenerator
import java.security.spec.ECGenParameterSpec
import java.time.LocalDateTime
import java.util.Base64
import java.util.UUID
import java.util.concurrent.CompletableFuture

class ApnsPushServiceTest {
    private val repository: ApnsInstallationRepository = mock()
    private val objectMapper = TestUtils.jsr310JsonMapper()

    @Test
    fun `sender is a no-op until Apple credentials are configured`() {
        val service = ApnsPushService(repository, objectMapper, "", "", "")

        assertDoesNotThrow {
            service.sendToMember(
                memberId = 1L,
                payload = PushNotificationPayload(type = NotificationType.FRIEND_REQUEST_RECEIVED),
            )
        }

        verify(repository, never()).findAllDeliverableByMemberId(any(), any())
    }

    @Test
    fun `sender uses sandbox host and minimal localized payload`() {
        val httpClient: HttpClient = mock()
        val response: HttpResponse<String> = mock()
        whenever(response.statusCode()).thenReturn(200)
        whenever(httpClient.sendAsync(any(), any<HttpResponse.BodyHandler<String>>()))
            .thenReturn(CompletableFuture.completedFuture(response))
        whenever(repository.findAllDeliverableByMemberId(any(), any())).thenReturn(
            listOf(ApnsInstallation(refreshToken(), "abc123", sandbox = true))
        )
        val service = enabledService(httpClient)

        service.sendToMember(
            1L,
            PushNotificationPayload(
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                notificationId = "notification-id",
                unreadCount = 3,
                url = "/friends",
            ),
        )

        val requestCaptor = argumentCaptor<HttpRequest>()
        verify(httpClient).sendAsync(requestCaptor.capture(), any<HttpResponse.BodyHandler<String>>())
        val request = requestCaptor.firstValue
        assertThat(request.uri().host).isEqualTo("api.sandbox.push.apple.com")
        assertThat(request.headers().firstValue("apns-topic")).hasValue("io.github.shanepark.dutypark")
        assertThat(request.headers().firstValue("authorization").orElse("")).startsWith("bearer ")

        val body = request.bodyPublisher().orElseThrow().let { publisher ->
            val subscriber = BodySubscriber()
            publisher.subscribe(subscriber)
            subscriber.body.join().decodeToString()
        }
        assertThat(body).contains("notifications.items.friendRequestReceivedFallback")
        assertThat(body).contains("\"badge\":3")
        assertThat(body).contains("\"notificationId\":\"notification-id\"")
        assertThat(body).contains("\"url\":\"/friends\"")
    }

    @Test
    fun `sender removes only installation rejected as unregistered`() {
        val httpClient: HttpClient = mock()
        val response: HttpResponse<String> = mock()
        whenever(response.statusCode()).thenReturn(410)
        whenever(httpClient.sendAsync(any(), any<HttpResponse.BodyHandler<String>>()))
            .thenReturn(CompletableFuture.completedFuture(response))
        val installation = ApnsInstallation(
            refreshToken(),
            "expired-token",
            sandbox = false,
        )
        whenever(repository.findAllDeliverableByMemberId(any(), any())).thenReturn(listOf(installation))

        enabledService(httpClient).sendToMember(
            1L,
            PushNotificationPayload(type = NotificationType.FRIEND_REQUEST_ACCEPTED),
        )

        val requestCaptor = argumentCaptor<HttpRequest>()
        verify(httpClient).sendAsync(requestCaptor.capture(), any<HttpResponse.BodyHandler<String>>())
        assertThat(requestCaptor.firstValue.uri().host).isEqualTo("api.push.apple.com")
        verify(repository).delete(installation)
    }

    @Test
    fun `payload passes actor as localization argument`() {
        val notification = NotificationDto(
            id = UUID.randomUUID(),
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = null,
            referenceId = null,
            actorId = 2L,
            payload = FriendRequestReceivedPayload(
                actor = NotificationActorSnapshot("Shane", false, 0),
            ),
            isRead = false,
            createdAt = LocalDateTime.now(),
        )
        val service = ApnsPushService(repository, objectMapper, "", "", "")

        val result = service.buildPayload(
            PushNotificationPayload(type = NotificationType.FRIEND_REQUEST_RECEIVED, notification = notification)
        )

        @Suppress("UNCHECKED_CAST")
        val aps = result["aps"] as Map<String, Any>
        @Suppress("UNCHECKED_CAST")
        val alert = aps["alert"] as Map<String, Any>
        assertThat(alert["loc-key"]).isEqualTo("notifications.items.friendRequestReceived")
        assertThat(alert["loc-args"]).isEqualTo(listOf("Shane"))
    }

    private fun enabledService(httpClient: HttpClient) = ApnsPushService(
        repository,
        objectMapper,
        "TEAMID123",
        "KEYID123",
        privateKeyPem(),
        httpClient,
    )

    private fun refreshToken(): RefreshToken = RefreshToken(
        member = Member("member", "member@duty.park", "password"),
        validUntil = LocalDateTime.now().plusDays(1),
        remoteAddr = null,
        userAgent = null,
    )

    private fun privateKeyPem(): String {
        val generator = KeyPairGenerator.getInstance("EC")
        generator.initialize(ECGenParameterSpec("secp256r1"))
        val encoded = Base64.getEncoder().encodeToString(generator.generateKeyPair().private.encoded)
        return "-----BEGIN PRIVATE KEY-----\n$encoded\n-----END PRIVATE KEY-----"
    }

    private class BodySubscriber : java.util.concurrent.Flow.Subscriber<java.nio.ByteBuffer> {
        val body = CompletableFuture<ByteArray>()
        private val bytes = mutableListOf<Byte>()

        override fun onSubscribe(subscription: java.util.concurrent.Flow.Subscription) = subscription.request(Long.MAX_VALUE)

        override fun onNext(item: java.nio.ByteBuffer) {
            while (item.hasRemaining()) bytes += item.get()
        }

        override fun onError(throwable: Throwable) = body.completeExceptionally(throwable).let { Unit }

        override fun onComplete() = body.complete(bytes.toByteArray()).let { Unit }
    }
}
