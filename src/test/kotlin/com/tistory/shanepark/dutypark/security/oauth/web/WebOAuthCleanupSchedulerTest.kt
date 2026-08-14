package com.tistory.shanepark.dutypark.security.oauth.web

import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class WebOAuthCleanupSchedulerTest {
    private val repository: WebOAuthTransactionRepository = mock()
    private val clock = Clock.fixed(Instant.parse("2026-08-14T00:00:00Z"), ZoneOffset.UTC)
    private val scheduler = WebOAuthCleanupScheduler(repository, clock)

    @Test
    fun `cleanup keeps a one day replay rejection grace period`() {
        scheduler.cleanupExpiredTransactions()

        verify(repository).deleteAllByStateExpiresAtBefore(Instant.parse("2026-08-13T00:00:00Z"))
    }
}
