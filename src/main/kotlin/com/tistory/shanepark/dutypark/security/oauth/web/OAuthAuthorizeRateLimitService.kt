package com.tistory.shanepark.dutypark.security.oauth.web

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.config.OAuthAuthorizeRateLimitConfig
import com.tistory.shanepark.dutypark.security.domain.entity.LoginAttempt
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Isolation
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime

@Service
class OAuthAuthorizeRateLimitService(
    private val loginAttemptRepository: LoginAttemptRepository,
    private val config: OAuthAuthorizeRateLimitConfig,
    private val clock: Clock,
) {
    private val log = logger()

    @Transactional(
        propagation = Propagation.REQUIRES_NEW,
        isolation = Isolation.SERIALIZABLE,
    )
    fun acquire(ipAddress: String): Boolean {
        val now = LocalDateTime.now(clock)
        val since = now.minusMinutes(config.windowMinutes)
        val globalAttempts = loginAttemptRepository.countRecentFailedAttempts(
            ipAddress = GLOBAL_IP_KEY,
            email = GLOBAL_RATE_LIMIT_KEY,
            since = since,
        )
        if (globalAttempts >= config.globalMaxAttempts) {
            return false
        }
        val ipAttempts = loginAttemptRepository.countRecentFailedAttempts(
            ipAddress = ipAddress,
            email = IP_RATE_LIMIT_KEY,
            since = since,
        )
        if (ipAttempts >= config.maxAttempts) {
            return false
        }
        loginAttemptRepository.saveAllAndFlush(
            listOf(
                LoginAttempt(
                    ipAddress = GLOBAL_IP_KEY,
                    email = GLOBAL_RATE_LIMIT_KEY,
                    attemptTime = now,
                    success = false,
                ),
                LoginAttempt(
                    ipAddress = ipAddress,
                    email = IP_RATE_LIMIT_KEY,
                    attemptTime = now,
                    success = false,
                ),
            )
        )
        return true
    }

    @Scheduled(cron = "0 10 * * * *")
    @Transactional
    fun cleanupExpiredAttempts() {
        val threshold = LocalDateTime.now(clock).minusMinutes(config.windowMinutes)
        val deleted = loginAttemptRepository.deleteAllByEmailInAndAttemptTimeBefore(
            keys = RATE_LIMIT_KEYS,
            threshold = threshold,
        )
        if (deleted > 0) {
            log.info("Cleaned up {} expired OAuth authorize rate-limit attempts", deleted)
        }
    }

    companion object {
        private const val GLOBAL_IP_KEY = "__global__"
        private const val GLOBAL_RATE_LIMIT_KEY = "__oauth_authorize_global__"
        private const val IP_RATE_LIMIT_KEY = "__oauth_authorize_ip__"
        private val RATE_LIMIT_KEYS = setOf(GLOBAL_RATE_LIMIT_KEY, IP_RATE_LIMIT_KEY)
    }
}
