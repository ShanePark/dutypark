package com.tistory.shanepark.dutypark.security.oauth

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.net.URI

@Component
class OAuthWebBaseUrl(
    @param:Value("\${oauth.web-base-url:http://localhost:8080}") configuredValue: String,
) {
    val origin: String = validate(configuredValue)

    fun callbackUri(path: String): String = "$origin/${path.trimStart('/')}"

    private fun validate(value: String): String {
        val normalized = value.removeSuffix("/")
        val uri = runCatching { URI(normalized) }
            .getOrElse { throw IllegalStateException("oauth.web-base-url must be an absolute origin") }
        val isOrigin = uri.host != null && uri.rawUserInfo == null && uri.rawQuery == null &&
            uri.rawFragment == null && uri.rawPath.orEmpty().isEmpty()
        val isSecure = uri.scheme.equals("https", ignoreCase = true)
        val isDevelopmentOrigin = normalized in DEVELOPMENT_ORIGINS
        check(isOrigin && (isSecure || isDevelopmentOrigin)) {
            "oauth.web-base-url must be an HTTPS origin or an approved local development origin"
        }
        return normalized
    }

    companion object {
        private val DEVELOPMENT_ORIGINS = setOf(
            "http://localhost:8080",
            "http://127.0.0.1:8080",
        )
    }
}
