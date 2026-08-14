package com.tistory.shanepark.dutypark.security.oauth.web

import com.tistory.shanepark.dutypark.security.config.OAuthAuthorizeRateLimitConfig
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import java.time.Clock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset

class OAuthAuthorizeRateLimitServiceTest {
    private val repository: LoginAttemptRepository = mock()
    private val clock = Clock.fixed(Instant.parse("2026-08-14T00:00:00Z"), ZoneOffset.UTC)
    private val service = OAuthAuthorizeRateLimitService(
        loginAttemptRepository = repository,
        config = OAuthAuthorizeRateLimitConfig(),
        clock = clock,
    )

    @Test
    fun `cleanup uses the configured rate limit window`() {
        service.cleanupExpiredAttempts()

        verify(repository).deleteAllByEmailInAndAttemptTimeBefore(
            keys = setOf("__oauth_authorize_global__", "__oauth_authorize_ip__"),
            threshold = LocalDateTime.of(2026, 8, 13, 23, 45),
        )
    }
}
