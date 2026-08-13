package com.tistory.shanepark.dutypark.security.oauth.apple

import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime

@Component
class AppleOAuthCleanupScheduler(
    private val replayRepository: AppleIdentityTokenReplayRepository,
    private val credentialRepository: AppleOAuthCredentialRepository,
    private val credentialService: AppleCredentialService,
    private val clock: Clock,
) {
    @Scheduled(cron = "0 23 4 * * *")
    @Transactional
    fun cleanup() {
        val now = LocalDateTime.ofInstant(clock.instant(), java.time.ZoneOffset.UTC)
        replayRepository.deleteByExpiresAtBefore(now.minusDays(1))
        credentialRepository.findOrphansUpdatedBefore(now.minusDays(1))
            .forEach { credentialService.revokeAndDelete(it.socialId) }
    }
}
