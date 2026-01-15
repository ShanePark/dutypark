package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.config.LoginRateLimitConfig
import com.tistory.shanepark.dutypark.security.domain.entity.LoginAttempt
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime

@Service
@Transactional
class LoginAttemptService(
    private val loginAttemptRepository: LoginAttemptRepository,
    private val config: LoginRateLimitConfig,
    private val clock: Clock
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun isBlocked(ipAddress: String, email: String): Boolean {
        val since = LocalDateTime.now(clock).minusMinutes(config.windowMinutes)
        val failedAttempts = loginAttemptRepository.countRecentFailedAttempts(
            ipAddress = ipAddress,
            email = email.lowercase(),
            since = since
        )
        return failedAttempts >= config.maxAttempts
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun recordFailedAttempt(ipAddress: String, email: String) {
        val attempt = LoginAttempt(
            ipAddress = ipAddress,
            email = email.lowercase(),
            attemptTime = LocalDateTime.now(clock),
            success = false
        )
        loginAttemptRepository.save(attempt)
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun recordSuccessfulAttempt(ipAddress: String, email: String) {
        val attempt = LoginAttempt(
            ipAddress = ipAddress,
            email = email.lowercase(),
            attemptTime = LocalDateTime.now(clock),
            success = true
        )
        loginAttemptRepository.save(attempt)
    }

    @Scheduled(cron = "0 0 3 * * *")
    @Transactional
    fun cleanupOldAttempts() {
        val threshold = LocalDateTime.now(clock).minusDays(config.cleanupRetentionDays)
        val deletedCount = loginAttemptRepository.deleteAllByAttemptTimeBefore(threshold)

        if (deletedCount > 0) {
            log.info("Cleaned up {} old login attempts before {}", deletedCount, threshold)
        }
    }

    @Transactional(readOnly = true)
    fun getRemainingAttempts(ipAddress: String, email: String): Int {
        val since = LocalDateTime.now(clock).minusMinutes(config.windowMinutes)
        val failedAttempts = loginAttemptRepository.countRecentFailedAttempts(
            ipAddress = ipAddress,
            email = email.lowercase(),
            since = since
        )
        return (config.maxAttempts - failedAttempts.toInt()).coerceAtLeast(0)
    }

}
