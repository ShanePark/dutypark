package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "cookie")
data class CookieConfig(
    val secure: Boolean = true,
    val sameSite: String = "Strict",
    val domain: String? = null,
)
