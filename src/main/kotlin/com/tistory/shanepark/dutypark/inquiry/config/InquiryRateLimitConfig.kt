package com.tistory.shanepark.dutypark.inquiry.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "dutypark.inquiry.rate-limit")
data class InquiryRateLimitConfig(
    val maxPerHour: Int = 5,
)
