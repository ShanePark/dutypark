package com.tistory.shanepark.dutypark.security.oauth.web

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.OAuthWebBaseUrl
import jakarta.servlet.http.HttpServletRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.dao.TransientDataAccessException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.util.UriComponentsBuilder
import java.net.URI
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Clock
import java.time.Duration
import java.util.Base64

@Service
class WebOAuthService(
    private val transactionRepository: WebOAuthTransactionRepository,
    private val clock: Clock,
    private val oauthWebBaseUrl: OAuthWebBaseUrl,
    private val authorizeRateLimitService: OAuthAuthorizeRateLimitService,
    @param:Value("\${oauth.kakao.rest-api-key}") private val kakaoClientId: String,
    @param:Value("\${oauth.naver.client-id}") private val naverClientId: String,
) {
    private val secureRandom = SecureRandom()

    @Transactional
    fun authorize(
        request: WebOAuthAuthorizeRequest,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): WebOAuthAuthorizeResponse {
        val provider = parseProvider(request.provider)
        val purpose = parsePurpose(request.purpose)
        val referer = validateReferer(request.referer)
        val memberId = when (purpose) {
            WebOAuthPurpose.LOGIN -> null
            WebOAuthPurpose.LINK -> loginMember?.id ?: throw AuthException()
        }
        val quotaAcquired = try {
            authorizeRateLimitService.acquire(servletRequest.remoteAddr)
        } catch (_: TransientDataAccessException) {
            false
        }
        if (!quotaAcquired) throw RateLimitException()
        val state = randomToken()
        val now = clock.instant()
        val sessionId = servletRequest.getSession(true).id
        transactionRepository.save(
            WebOAuthTransaction(
                provider = provider,
                purpose = purpose,
                referer = referer,
                stateHash = sha256Hex(state),
                browserSessionHash = sha256Hex(sessionId),
                stateExpiresAt = now.plus(STATE_TTL),
                authenticatedMemberId = memberId,
            )
        )

        val callbackUri = callbackUri(provider)
        val authorizationUrl = when (provider) {
            SsoType.KAKAO -> UriComponentsBuilder.fromUriString("https://kauth.kakao.com/oauth/authorize")
                .queryParam("response_type", "code")
                .queryParam("client_id", kakaoClientId)
                .queryParam("redirect_uri", callbackUri)
                .queryParam("state", state)
                .build().encode().toUriString()

            SsoType.NAVER -> UriComponentsBuilder.fromUriString("https://nid.naver.com/oauth2.0/authorize")
                .queryParam("response_type", "code")
                .queryParam("client_id", naverClientId)
                .queryParam("redirect_uri", callbackUri)
                .queryParam("state", state)
                .build().encode().toUriString()

            SsoType.APPLE -> error("Unsupported web OAuth provider")
        }
        return WebOAuthAuthorizeResponse(authorizationUrl, STATE_TTL.seconds)
    }

    @Transactional
    fun claim(
        provider: SsoType,
        state: String,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): WebOAuthClaim {
        val now = clock.instant()
        val browserSession = servletRequest.getSession(false)?.id ?: throw WebOAuthStateException()
        val transaction = transactionRepository.findByStateHashForUpdate(sha256Hex(state))
            .orElseThrow(::WebOAuthStateException)
        val memberMatches = when (transaction.purpose) {
            WebOAuthPurpose.LOGIN -> true
            WebOAuthPurpose.LINK -> loginMember?.id == transaction.authenticatedMemberId
        }
        if (
            transaction.provider != provider || transaction.stateConsumedAt != null ||
            !now.isBefore(transaction.stateExpiresAt) ||
            !secureEquals(transaction.browserSessionHash, sha256Hex(browserSession)) ||
            !memberMatches
        ) {
            throw WebOAuthStateException()
        }
        transaction.consume(now)
        return WebOAuthClaim(transaction.purpose, transaction.referer)
    }

    fun callbackUri(provider: SsoType): String =
        oauthWebBaseUrl.callbackUri("api/auth/Oauth2ClientCallback/${provider.name.lowercase()}")

    private fun validateReferer(value: String): String {
        var candidate = value
        repeat(MAX_DECODE_PASSES) {
            validateRelativeUri(candidate)
            val decoded = runCatching { URLDecoder.decode(candidate, StandardCharsets.UTF_8) }
                .getOrElse { throw BadRequestException("auth.oauth.web.referer.invalid") }
            if (decoded == candidate) return candidate
            candidate = decoded
        }
        validateRelativeUri(candidate)
        return value
    }

    private fun validateRelativeUri(value: String) {
        val uri = runCatching { URI(value) }
            .getOrElse { throw BadRequestException("auth.oauth.web.referer.invalid") }
        val valid = value.startsWith('/') && !value.startsWith("//") && '\\' !in value &&
            value.none { it.isISOControl() } && uri.scheme == null && uri.host == null &&
            uri.rawAuthority == null && uri.rawUserInfo == null && uri.rawPath.startsWith('/') &&
            !uri.rawPath.startsWith("//")
        if (!valid) throw BadRequestException("auth.oauth.web.referer.invalid")
    }

    private fun parseProvider(value: String): SsoType = when (value.uppercase()) {
        SsoType.KAKAO.name -> SsoType.KAKAO
        SsoType.NAVER.name -> SsoType.NAVER
        else -> throw BadRequestException("auth.oauth.web.provider.invalid")
    }

    private fun parsePurpose(value: String): WebOAuthPurpose = runCatching {
        WebOAuthPurpose.valueOf(value.uppercase())
    }.getOrElse { throw BadRequestException("auth.oauth.web.purpose.invalid") }

    private fun randomToken(): String = ByteArray(32).also(secureRandom::nextBytes)
        .let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private fun secureEquals(first: String, second: String): Boolean = MessageDigest.isEqual(
        first.toByteArray(StandardCharsets.US_ASCII),
        second.toByteArray(StandardCharsets.US_ASCII),
    )

    companion object {
        private val STATE_TTL: Duration = Duration.ofMinutes(5)
        private const val MAX_DECODE_PASSES = 3
    }
}

data class WebOAuthClaim(
    val purpose: WebOAuthPurpose,
    val referer: String,
)

class WebOAuthStateException : RuntimeException()
