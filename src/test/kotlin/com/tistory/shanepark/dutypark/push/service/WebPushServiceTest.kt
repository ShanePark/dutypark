package com.tistory.shanepark.dutypark.push.service

import tools.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionKeys
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionRequest
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import nl.martijndwars.webpush.PushService
import org.apache.http.ProtocolVersion
import org.apache.http.message.BasicHttpResponse
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.never
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.Security
import java.security.SecureRandom
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.time.LocalDateTime
import java.util.Base64
import org.bouncycastle.jce.provider.BouncyCastleProvider

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class WebPushServiceTest {

    private val refreshTokenRepository: RefreshTokenRepository = mock()
    private val objectMapper: ObjectMapper = mock()
    private val pushService: PushService = mock()

    private lateinit var service: WebPushService

    @BeforeEach
    fun setUp() {
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.addProvider(BouncyCastleProvider())
        }
        service = WebPushService(
            refreshTokenRepository = refreshTokenRepository,
            objectMapper = objectMapper,
            pushService = pushService
        )
    }

    @Test
    fun `subscribe returns false when push disabled`() {
        val disabledService = WebPushService(refreshTokenRepository, objectMapper, null)
        val token = refreshTokenWithId(1L, memberWithId(1L))

        val result = disabledService.subscribe(
            refreshToken = token,
            request = PushSubscriptionRequest(
                endpoint = "endpoint",
                keys = PushSubscriptionKeys(p256dh = "p256dh", auth = "auth")
            )
        )

        assertThat(result).isFalse
    }

    @Test
    fun `subscribe replaces existing token with same endpoint`() {
        val existing = refreshTokenWithId(1L, memberWithId(1L))
        existing.subscribePush("endpoint", "p256dh", "auth")
        val current = refreshTokenWithId(2L, memberWithId(1L))

        whenever(refreshTokenRepository.findByPushEndpoint("endpoint")).thenReturn(existing)

        val result = service.subscribe(
            refreshToken = current,
            request = PushSubscriptionRequest(
                endpoint = "endpoint",
                keys = PushSubscriptionKeys(p256dh = "p256dh2", auth = "auth2")
            )
        )

        assertThat(result).isTrue
        assertThat(existing.hasPushSubscription()).isFalse
        assertThat(current.hasPushSubscription()).isTrue
        verify(refreshTokenRepository).saveAndFlush(existing)
        verify(refreshTokenRepository).save(current)
    }

    @Test
    fun `unsubscribe returns false when no subscription`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))

        val result = service.unsubscribe(token)

        assertThat(result).isFalse
        verify(refreshTokenRepository, never()).save(any())
    }

    @Test
    fun `unsubscribe clears subscription when present`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        token.subscribePush("endpoint", "p256dh", "auth")

        val result = service.unsubscribe(token)

        assertThat(result).isTrue
        assertThat(token.hasPushSubscription()).isFalse
        verify(refreshTokenRepository).save(token)
    }

    @Test
    fun `sendToMember skips when payload serialization fails`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        token.subscribePush("endpoint", "p256dh", "auth")
        whenever(
            refreshTokenRepository.findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
        ).thenReturn(listOf(token))
        whenever(objectMapper.writeValueAsString(any())).thenThrow(RuntimeException("serialize"))

        service.sendToMember(1L, PushNotificationPayload(body = "body"))

        verify(pushService, never()).send(any())
    }

    @Test
    fun `sendToMember removes token when subscription data missing`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        token.subscribePush("endpoint", "p256dh", "auth")
        token.pushP256dh = ""
        whenever(
            refreshTokenRepository.findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
        ).thenReturn(listOf(token))
        whenever(objectMapper.writeValueAsString(any())).thenReturn("{\"body\":\"body\"}")

        service.sendToMember(1L, PushNotificationPayload(body = "body"))

        assertThat(token.hasPushSubscription()).isFalse
        verify(refreshTokenRepository).save(token)
    }

    @Test
    fun `sendToMember returns early when push is disabled`() {
        val disabledService = WebPushService(refreshTokenRepository, objectMapper, null)

        disabledService.sendToMember(1L, PushNotificationPayload(body = "body"))

        verify(refreshTokenRepository, never()).findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
    }

    @Test
    fun `sendToMember returns early when no tokens`() {
        whenever(
            refreshTokenRepository.findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
        ).thenReturn(emptyList())

        service.sendToMember(1L, PushNotificationPayload(body = "body"))

        verify(objectMapper, never()).writeValueAsString(any())
        verify(pushService, never()).send(any())
    }

    @Test
    fun `sendToMember unsubscribes token on 410 response`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        subscribeValidPush(token)
        whenever(
            refreshTokenRepository.findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
        ).thenReturn(listOf(token))
        whenever(objectMapper.writeValueAsString(any())).thenReturn("{\"body\":\"body\"}")

        val response = BasicHttpResponse(ProtocolVersion("HTTP", 1, 1), 410, "Gone")
        whenever(pushService.send(any<nl.martijndwars.webpush.Notification>())).thenReturn(response)

        service.sendToMember(1L, PushNotificationPayload(body = "body"))

        assertThat(token.hasPushSubscription()).isFalse
        verify(refreshTokenRepository).save(token)
    }

    @Test
    fun `sendToMember keeps token on non-2xx response`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        subscribeValidPush(token)
        whenever(
            refreshTokenRepository.findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
        ).thenReturn(listOf(token))
        whenever(objectMapper.writeValueAsString(any())).thenReturn("{\"body\":\"body\"}")

        val response = BasicHttpResponse(ProtocolVersion("HTTP", 1, 1), 500, "Error")
        whenever(pushService.send(any<nl.martijndwars.webpush.Notification>())).thenReturn(response)

        service.sendToMember(1L, PushNotificationPayload(body = "body"))

        assertThat(token.hasPushSubscription()).isTrue
        verify(refreshTokenRepository, never()).save(token)
    }

    @Test
    fun `handleSendError unsubscribes token when expired`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        token.subscribePush("endpoint", "p256dh", "auth")
        val method = WebPushService::class.java.getDeclaredMethod(
            "handleSendError",
            RefreshToken::class.java,
            Exception::class.java
        )
        method.isAccessible = true
        method.invoke(service, token, RuntimeException("410 Gone"))

        assertThat(token.hasPushSubscription()).isFalse
        verify(refreshTokenRepository).save(token)
    }

    @Test
    fun `sendToMember keeps token when send throws other errors`() {
        val token = refreshTokenWithId(1L, memberWithId(1L))
        subscribeValidPush(token)
        whenever(
            refreshTokenRepository.findAllByMemberIdAndPushEndpointIsNotNullAndValidUntilAfter(any(), any())
        ).thenReturn(listOf(token))
        whenever(objectMapper.writeValueAsString(any())).thenReturn("{\"body\":\"body\"}")
        whenever(pushService.send(any<nl.martijndwars.webpush.Notification>())).thenThrow(RuntimeException("network error"))

        service.sendToMember(1L, PushNotificationPayload(body = "body"))

        assertThat(token.hasPushSubscription()).isTrue
        verify(refreshTokenRepository, never()).save(token)
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }

    private fun refreshTokenWithId(id: Long, member: Member): RefreshToken {
        val token = RefreshToken(
            member = member,
            validUntil = LocalDateTime.now().plusDays(1),
            remoteAddr = "127.0.0.1",
            userAgent = null
        )
        val field = RefreshToken::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(token, id)
        return token
    }

    private fun subscribeValidPush(token: RefreshToken) {
        val keys = generateKeys()
        token.subscribePush("https://example.com/endpoint", keys.p256dh, keys.auth)
    }

    private data class WebPushKeys(val p256dh: String, val auth: String)

    private fun generateKeys(): WebPushKeys {
        val keyPairGenerator = KeyPairGenerator.getInstance("EC")
        keyPairGenerator.initialize(ECGenParameterSpec("secp256r1"))
        val keyPair = keyPairGenerator.generateKeyPair()
        val publicKey = keyPair.public as ECPublicKey

        val xBytes = toFixedLength(publicKey.w.affineX, 32)
        val yBytes = toFixedLength(publicKey.w.affineY, 32)
        val rawKey = ByteArray(65)
        rawKey[0] = 0x04
        System.arraycopy(xBytes, 0, rawKey, 1, 32)
        System.arraycopy(yBytes, 0, rawKey, 33, 32)

        val encoder = Base64.getUrlEncoder().withoutPadding()
        val p256dh = encoder.encodeToString(rawKey)
        val authBytes = ByteArray(16)
        SecureRandom().nextBytes(authBytes)
        val auth = encoder.encodeToString(authBytes)
        return WebPushKeys(p256dh, auth)
    }

    private fun toFixedLength(value: BigInteger, size: Int): ByteArray {
        val bytes = value.toByteArray()
        return when {
            bytes.size == size -> bytes
            bytes.size < size -> ByteArray(size - bytes.size) + bytes
            else -> bytes.copyOfRange(bytes.size - size, bytes.size)
        }
    }
}
