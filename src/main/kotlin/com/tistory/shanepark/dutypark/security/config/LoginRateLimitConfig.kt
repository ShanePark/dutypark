package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "dutypark.login.rate-limit")
data class LoginRateLimitConfig(
    val maxAttempts: Int = 5,
    val windowMinutes: Long = 15,
    val cleanupRetentionDays: Long = 7
)
