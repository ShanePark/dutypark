package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "jwt")
data class JwtConfig(
    val secret: String,
    val tokenValidityInSeconds: Long,
    val refreshTokenValidityInDays: Long
)
