package com.tistory.shanepark.dutypark.security.oauth

import com.tistory.shanepark.dutypark.security.config.CookieConfig
import org.springframework.stereotype.Component
import java.net.URI

@Component
class OAuthFrontendBaseUrl(
    cookieConfig: CookieConfig,
) {
    val origin: String = cookieConfig.domain
        ?.takeIf { it.isNotBlank() }
        ?.let { "https://${it.trim('.').lowercase()}" }
        ?: LOCAL_FRONTEND_ORIGIN

    fun uri(path: String): URI = URI.create("$origin/${path.trimStart('/')}")

    companion object {
        private const val LOCAL_FRONTEND_ORIGIN = "http://localhost:5173"
    }
}
