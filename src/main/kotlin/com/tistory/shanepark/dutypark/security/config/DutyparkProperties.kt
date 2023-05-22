package com.tistory.shanepark.dutypark.security.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "dutypark")
data class DutyparkProperties(
    val adminEmails: List<String> = emptyList(),
    val whiteIpList: List<String> = emptyList()
)
