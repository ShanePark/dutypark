package com.tistory.shanepark.dutypark.security.oauth.web

import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Duration

@Service
class WebOAuthCleanupScheduler(
    private val transactionRepository: WebOAuthTransactionRepository,
    private val clock: Clock,
) {
    private val log = logger()

    @Scheduled(cron = "0 25 3 * * *")
    @Transactional
    fun cleanupExpiredTransactions() {
        val threshold = clock.instant().minus(CLEANUP_GRACE_PERIOD)
        val deleted = transactionRepository.deleteAllByStateExpiresAtBefore(threshold)
        if (deleted > 0) {
            log.info("Cleaned up {} expired web OAuth transactions", deleted)
        }
    }

    companion object {
        private val CLEANUP_GRACE_PERIOD: Duration = Duration.ofDays(1)
    }
}
