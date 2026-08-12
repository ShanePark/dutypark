package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration

@Service
class MobileOAuthCleanupScheduler(
    private val transactionRepository: MobileOAuthTransactionRepository,
    private val clock: Clock,
) {
    private val log = logger()

    @Scheduled(cron = "0 15 3 * * *")
    @Transactional
    fun cleanupExpiredTransactions() {
        // This grace period is much longer than both configured one-time token TTLs.
        val threshold = clock.instant().minus(Duration.ofDays(1))
        val deleted = transactionRepository.deleteAllByStateExpiresAtBefore(threshold)
        if (deleted > 0) {
            log.info("Cleaned up {} expired mobile OAuth transactions", deleted)
        }
    }
}
