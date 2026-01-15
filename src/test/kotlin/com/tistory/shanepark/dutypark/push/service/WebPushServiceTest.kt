package com.tistory.shanepark.dutypark.push.service

import tools.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionKeys
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionRequest
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import nl.martijndwars.webpush.PushService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.never
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.LocalDateTime

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class WebPushServiceTest {

    private val refreshTokenRepository: RefreshTokenRepository = mock()
    private val objectMapper: ObjectMapper = mock()
    private val pushService: PushService = mock()

    private lateinit var service: WebPushService

    @BeforeEach
    fun setUp() {
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
}
