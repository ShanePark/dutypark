package com.tistory.shanepark.dutypark.common.config

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.Duration

@ConfigurationProperties(prefix = "dutypark.ai")
data class AiProperties(
    val chat: ChatProperties = ChatProperties()
) {
    data class ChatProperties(
        val connectTimeout: Duration = Duration.ofSeconds(30),
        val readTimeout: Duration = Duration.ofMinutes(2)
    )
}
