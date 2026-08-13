package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.stereotype.Component
import org.springframework.beans.factory.annotation.Autowired
import tools.jackson.databind.ObjectMapper
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.time.Duration

interface AppleProviderClient {
    fun jwks(): AppleJwks
    fun exchange(code: String, clientId: String, clientSecret: String): AppleTokenResponse
    fun revoke(refreshToken: String, clientId: String, clientSecret: String)
}

@Component
class AppleProviderHttpClient @Autowired constructor(
    private val objectMapper: ObjectMapper,
) : AppleProviderClient {
    private val log = logger()
    private var httpClient = HttpClient.newBuilder().connectTimeout(TIMEOUT).build()

    internal constructor(objectMapper: ObjectMapper, httpClient: HttpClient) : this(objectMapper) {
        this.httpClient = httpClient
    }

    override fun jwks(): AppleJwks {
        val request = HttpRequest.newBuilder(JWKS_URI).timeout(TIMEOUT).GET().build()
        return send(request, AppleJwks::class.java)
    }

    override fun exchange(code: String, clientId: String, clientSecret: String): AppleTokenResponse {
        val request = formRequest(
            TOKEN_URI,
            mapOf(
                "grant_type" to "authorization_code",
                "code" to code,
                "client_id" to clientId,
                "client_secret" to clientSecret,
            ),
        )
        val response = sendRaw(request)
        if (response.statusCode() in 500..599) {
            log.warn("Apple token endpoint unavailable. status={}", response.statusCode())
            throw AppleOAuthException("auth.apple.provider.unavailable", 503)
        }
        if (response.statusCode() !in 200..299) {
            throw AppleOAuthException("auth.apple.credential.invalid")
        }
        return try {
            objectMapper.readValue(response.body(), AppleTokenResponse::class.java)
        } catch (e: Exception) {
            throw AppleOAuthException("auth.apple.credential.invalid", 401, e)
        }
    }

    override fun revoke(refreshToken: String, clientId: String, clientSecret: String) {
        val request = formRequest(
            REVOKE_URI,
            mapOf(
                "token" to refreshToken,
                "token_type_hint" to "refresh_token",
                "client_id" to clientId,
                "client_secret" to clientSecret,
            ),
        )
        val response = sendRaw(request)
        if (response.statusCode() !in 200..299) {
            log.warn("Apple credential revoke failed. status={}", response.statusCode())
            throw AppleOAuthException("auth.apple.provider.unavailable", 503)
        }
    }

    private fun formRequest(uri: URI, values: Map<String, String>): HttpRequest {
        val body = values.entries.joinToString("&") { (key, value) ->
            "${encode(key)}=${encode(value)}"
        }
        return HttpRequest.newBuilder(uri)
            .timeout(TIMEOUT)
            .header("Content-Type", "application/x-www-form-urlencoded")
            .POST(HttpRequest.BodyPublishers.ofString(body))
            .build()
    }

    private fun <T> send(request: HttpRequest, type: Class<T>): T {
        val response = sendRaw(request)
        if (response.statusCode() !in 200..299) {
            log.warn("Apple provider request failed. status={}", response.statusCode())
            throw AppleOAuthException("auth.apple.provider.unavailable", 503)
        }
        return try {
            objectMapper.readValue(response.body(), type)
        } catch (e: Exception) {
            throw AppleOAuthException("auth.apple.provider.unavailable", 503, e)
        }
    }

    private fun sendRaw(request: HttpRequest): HttpResponse<String> = try {
        httpClient.send(request, HttpResponse.BodyHandlers.ofString())
    } catch (e: Exception) {
        log.warn("Apple provider network request failed. error={}", e.javaClass.simpleName)
        throw AppleOAuthException("auth.apple.provider.unavailable", 503, e)
    }

    private fun encode(value: String): String = URLEncoder.encode(value, StandardCharsets.UTF_8)

    companion object {
        private val TIMEOUT: Duration = Duration.ofSeconds(10)
        private val JWKS_URI = URI.create("https://appleid.apple.com/auth/keys")
        private val TOKEN_URI = URI.create("https://appleid.apple.com/auth/token")
        private val REVOKE_URI = URI.create("https://appleid.apple.com/auth/revoke")
    }
}
