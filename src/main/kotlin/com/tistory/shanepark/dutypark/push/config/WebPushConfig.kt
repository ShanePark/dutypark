package com.tistory.shanepark.dutypark.push.config

import com.tistory.shanepark.dutypark.common.config.logger
import nl.martijndwars.webpush.PushService
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.security.Security

@Configuration
class WebPushConfig {

    private val log = logger()

    @Value("\${dutypark.webpush.vapid.public-key:}")
    private lateinit var publicKey: String

    @Value("\${dutypark.webpush.vapid.private-key:}")
    private lateinit var privateKey: String

    init {
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.addProvider(BouncyCastleProvider())
        }
    }

    @Bean
    fun pushService(): PushService? {
        if (publicKey.isBlank() || privateKey.isBlank()) {
            log.info("Web Push is disabled: VAPID keys not configured")
            return null
        }
        log.info("Web Push is enabled")
        return PushService(publicKey, privateKey, "mailto:admin@dutypark.com")
    }
}
