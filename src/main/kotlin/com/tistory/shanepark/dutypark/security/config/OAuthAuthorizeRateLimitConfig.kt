package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "dutypark.oauth.authorize-rate-limit")
data class OAuthAuthorizeRateLimitConfig(
    val maxAttempts: Int = 30,
    val globalMaxAttempts: Int = 1_000,
    val windowMinutes: Long = 15,
)
