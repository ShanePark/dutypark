package com.tistory.shanepark.dutypark.security.oauth.apple

import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.Clock
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset

class AppleOAuthCleanupSchedulerTest {
    private val replayRepository: AppleIdentityTokenReplayRepository = mock()
    private val credentialRepository: AppleOAuthCredentialRepository = mock()
    private val credentialService: AppleCredentialService = mock()
    private val clock = Clock.fixed(Instant.parse("2026-08-14T00:00:00Z"), ZoneOffset.UTC)
    private val scheduler = AppleOAuthCleanupScheduler(
        replayRepository,
        credentialRepository,
        credentialService,
        clock,
    )

    @Test
    fun `orphan cleanup revokes each subject once when it has multiple client grants`() {
        whenever(credentialRepository.findOrphansUpdatedBefore(any())).thenReturn(
            listOf(
                credential("shared-subject", "native-client"),
                credential("shared-subject", "web-client"),
                credential("other-subject", "native-client"),
            )
        )

        scheduler.cleanup()

        verify(credentialService, times(1)).revokeAndDelete("shared-subject")
        verify(credentialService, times(1)).revokeAndDelete("other-subject")
    }

    private fun credential(subject: String, clientId: String) = AppleOAuthCredential(
        socialId = subject,
        clientId = clientId,
        encryptedRefreshToken = "encrypted-$clientId",
        createdAt = LocalDateTime.now(clock).minusDays(2),
        updatedAt = LocalDateTime.now(clock).minusDays(2),
    )
}
