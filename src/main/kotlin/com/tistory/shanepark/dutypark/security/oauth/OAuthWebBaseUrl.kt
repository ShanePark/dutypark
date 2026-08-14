package com.tistory.shanepark.dutypark.security.oauth

import com.tistory.shanepark.dutypark.security.config.CookieConfig
import org.springframework.stereotype.Component

@Component
class OAuthWebBaseUrl(
    cookieConfig: CookieConfig,
) {
    val origin: String = cookieConfig.domain
        ?.takeIf { it.isNotBlank() }
        ?.let { "https://${it.trim('.').lowercase()}" }
        ?: LOCAL_BACKEND_ORIGIN

    fun callbackUri(path: String): String = "$origin/${path.trimStart('/')}"

    companion object {
        private const val LOCAL_BACKEND_ORIGIN = "http://localhost:8080"
    }
}
