package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import com.tistory.shanepark.dutypark.security.reauth.ReauthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.support.TransactionTemplate
import org.springframework.web.util.UriComponentsBuilder
import java.net.URI
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Clock
import java.time.Duration
import java.util.Base64

@Service
class MobileOAuthService(
    private val transactionRepository: MobileOAuthTransactionRepository,
    private val providerGateway: MobileOAuthProviderGateway,
    private val memberSocialAccountService: MemberSocialAccountService,
    private val memberRepository: MemberRepository,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val authService: AuthService,
    private val reauthService: ReauthService,
    private val clock: Clock,
    transactionManager: PlatformTransactionManager,
    @param:Value("\${oauth.kakao.rest-api-key}") private val kakaoClientId: String,
    @param:Value("\${oauth.naver.client-id}") private val naverClientId: String,
    @param:Value("\${cookie.domain:}") cookieDomain: String,
) {
    private val log = logger()
    private val secureRandom = SecureRandom()
    private val callbackTransaction = TransactionTemplate(transactionManager)
    private val allowedWebCallbackUris = buildSet {
        DEVELOPMENT_WEB_ORIGINS.mapTo(this, ::webCallbackUriForOrigin)
        cookieDomainWebCallbackUri(cookieDomain)?.let(::add)
    }

    @Transactional
    fun authorize(
        request: MobileOAuthAuthorizeRequest,
        loginMember: LoginMember?,
        mobileOAuthBaseUrl: String,
    ): MobileOAuthAuthorizeResponse {
        val provider = parseProvider(request.provider)
        val purpose = parsePurpose(request.purpose)
        val authenticatedMemberId = when (purpose) {
            MobileOAuthPurpose.LOGIN -> null
            MobileOAuthPurpose.LINK -> loginMember?.id ?: throw AuthException()
            MobileOAuthPurpose.DELETE_ACCOUNT -> {
                val member = loginMember ?: throw AuthException()
                if (member.isImpersonating) {
                    throw AuthException("auth.reauth.impersonationForbidden")
                }
                member.id
            }
        }
        validateAppCallbackUri(purpose, request.callbackUri)
        val callbackUri = providerCallbackUri(mobileOAuthBaseUrl, provider)
        val state = randomToken()
        val now = clock.instant()
        transactionRepository.save(
            MobileOAuthTransaction(
                provider = provider,
                purpose = purpose,
                callbackUri = request.callbackUri,
                codeChallenge = request.codeChallenge,
                stateHash = sha256Hex(state),
                stateExpiresAt = now.plus(STATE_TTL),
                authenticatedMemberId = authenticatedMemberId,
            )
        )

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
        }
        return MobileOAuthAuthorizeResponse(authorizationUrl, STATE_TTL.seconds)
    }

    fun completeCallback(
        providerName: String,
        code: String?,
        state: String,
        error: String?,
        providerRedirectUri: String,
    ): URI {
        val provider = parseProvider(providerName)
        val claim = claim(provider, state)
        if (error != null) {
            return callbackUri(claim.callbackUri, "error", "oauth_cancelled")
        }
        if (code == null) {
            return callbackUri(claim.callbackUri, "error", "provider_failed")
        }

        val socialId = try {
            providerGateway.getSocialId(
                provider = provider,
                code = code,
                state = state,
                redirectUri = providerRedirectUri,
            )
        } catch (e: Exception) {
            log.warn("Mobile OAuth provider call failed. provider={}, error={}", provider, e.javaClass.simpleName)
            return callbackUri(claim.callbackUri, "error", "provider_failed")
        }

        return finalizeCallback(claim, socialId)
    }

    @Transactional
    fun exchange(request: MobileOAuthExchangeRequest, servletRequest: HttpServletRequest): MobileOAuthExchangeResult {
        val now = clock.instant()
        val transaction = transactionRepository.findByExchangeCodeHashForUpdate(sha256Hex(request.code))
            .orElseThrow { AuthException("auth.oauth.mobile.code.invalid") }
        val expiresAt = transaction.exchangeExpiresAt
        if (
            transaction.exchangeConsumedAt != null || expiresAt == null || !now.isBefore(expiresAt) ||
            transaction.callbackUri != request.callbackUri
        ) {
            throw AuthException("auth.oauth.mobile.code.invalid")
        }
        if (!verifyPkce(request.codeVerifier, transaction.codeChallenge)) {
            throw AuthException("auth.oauth.mobile.pkce.invalid")
        }

        transaction.consumeExchange(now)
        return when (transaction.purpose) {
            MobileOAuthPurpose.LOGIN -> exchangeLogin(transaction, servletRequest)
            MobileOAuthPurpose.DELETE_ACCOUNT -> exchangeAccountDeletionReauth(transaction)
            MobileOAuthPurpose.LINK -> throw AuthException("auth.oauth.mobile.code.invalid")
        }
    }

    private fun callbackUri(base: String, name: String, value: String): URI =
        UriComponentsBuilder.fromUriString(base).queryParam(name, value).build().encode().toUri()

    private fun claim(provider: SsoType, state: String): MobileOAuthClaim {
        return requireNotNull(callbackTransaction.execute {
            val now = clock.instant()
            val transaction = transactionRepository.findByStateHashForUpdate(sha256Hex(state))
                .orElseThrow { AuthException("auth.oauth.mobile.state.invalid") }
            if (
                transaction.provider != provider || transaction.stateConsumedAt != null ||
                !now.isBefore(transaction.stateExpiresAt)
            ) {
                throw AuthException("auth.oauth.mobile.state.invalid")
            }
            transaction.claim(now)
            MobileOAuthClaim(
                transactionId = requireNotNull(transaction.id),
                provider = transaction.provider,
                purpose = transaction.purpose,
                callbackUri = transaction.callbackUri,
                authenticatedMemberId = transaction.authenticatedMemberId,
            )
        })
    }

    private fun finalizeCallback(claim: MobileOAuthClaim, socialId: String): URI {
        return requireNotNull(callbackTransaction.execute {
            if (claim.purpose == MobileOAuthPurpose.LINK) {
                val member = memberRepository.findById(requireNotNull(claim.authenticatedMemberId)).orElseThrow {
                    AuthException("auth.token.memberNotFound")
                }
                return@execute try {
                    memberSocialAccountService.link(member, claim.provider, socialId)
                    callbackUri(claim.callbackUri, "linked", "success")
                } catch (_: SocialAccountAlreadyLinkedException) {
                    callbackUri(claim.callbackUri, "error", "already_linked")
                }
            }

            val transaction = transactionRepository.findById(claim.transactionId)
                .orElseThrow { AuthException("auth.oauth.mobile.state.invalid") }
            val member = memberSocialAccountService.findMemberByProviderAndSocialId(claim.provider, socialId)
            val exchangeCode = randomToken()
            val exchangeExpiresAt = clock.instant().plus(EXCHANGE_CODE_TTL)
            when (claim.purpose) {
                MobileOAuthPurpose.LOGIN -> {
                    if (member != null) {
                        transaction.completeForMember(sha256Hex(exchangeCode), exchangeExpiresAt, member.id!!)
                    } else {
                        val signup = memberSsoRegisterRepository.save(MemberSsoRegister(claim.provider, socialId))
                        transaction.completeForSignup(sha256Hex(exchangeCode), exchangeExpiresAt, signup.uuid)
                    }
                }

                MobileOAuthPurpose.DELETE_ACCOUNT -> {
                    val authenticatedMemberId = requireNotNull(claim.authenticatedMemberId)
                    if (member?.id != authenticatedMemberId) {
                        return@execute callbackUri(claim.callbackUri, "error", "reauth_account_mismatch")
                    }
                    transaction.completeForMember(
                        sha256Hex(exchangeCode),
                        exchangeExpiresAt,
                        authenticatedMemberId,
                    )
                }

                MobileOAuthPurpose.LINK -> error("LINK callback must return before exchange code creation")
            }
            callbackUri(claim.callbackUri, "code", exchangeCode)
        })
    }

    private fun exchangeLogin(
        transaction: MobileOAuthTransaction,
        servletRequest: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        val memberId = transaction.memberId
        if (memberId != null) {
            val tokens = authService.getTokenResponseByMemberId(memberId, servletRequest)
            return MobileOAuthExchangeResult(
                response = MobileOAuthExchangeResponse(false, expiresIn = tokens.expiresIn),
                accessToken = tokens.accessToken,
                refreshToken = tokens.refreshToken,
            )
        }
        return MobileOAuthExchangeResult(
            response = MobileOAuthExchangeResponse(true, signupUuid = transaction.signupUuid)
        )
    }

    private fun exchangeAccountDeletionReauth(transaction: MobileOAuthTransaction): MobileOAuthExchangeResult {
        val memberId = transaction.memberId
            ?: throw AuthException("auth.oauth.mobile.code.invalid")
        val proof = reauthService.issue(memberId, ReauthPurpose.DELETE_ACCOUNT)
        return MobileOAuthExchangeResult(
            response = MobileOAuthExchangeResponse(
                signupRequired = false,
                expiresIn = proof.expiresIn,
                reauthProof = proof.reauthProof,
            )
        )
    }

    private fun providerCallbackUri(mobileOAuthBaseUrl: String, provider: SsoType): String {
        return "${mobileOAuthBaseUrl.trimEnd('/')}/callback/${provider.name.lowercase()}"
    }

    private fun validateAppCallbackUri(purpose: MobileOAuthPurpose, callbackUri: String) {
        val allowed = when (purpose) {
            MobileOAuthPurpose.LOGIN, MobileOAuthPurpose.LINK -> callbackUri == APP_CALLBACK_URI
            MobileOAuthPurpose.DELETE_ACCOUNT ->
                callbackUri == APP_CALLBACK_URI || callbackUri in allowedWebCallbackUris
        }
        require(allowed) { "auth.oauth.mobile.callback.notAllowed" }
    }

    private fun webCallbackUriForOrigin(configuredOrigin: String): String {
        val origin = configuredOrigin.removeSuffix("/")
        val uri = runCatching { URI(origin) }.getOrElse {
            throw IllegalStateException("Invalid OAuth mobile web callback origin")
        }
        val isOriginOnly = uri.host != null && uri.rawUserInfo == null && uri.rawQuery == null &&
            uri.rawFragment == null && uri.rawPath.orEmpty().isEmpty()
        val isSecure = uri.scheme.equals("https", ignoreCase = true)
        val isExactDevelopmentOrigin = origin in DEVELOPMENT_WEB_ORIGINS
        check(isOriginOnly && (isSecure || isExactDevelopmentOrigin)) {
            "OAuth mobile web callback origins must be HTTPS origins or approved local development origins"
        }
        return "$origin$WEB_ACCOUNT_DELETION_CALLBACK_PATH"
    }

    private data class MobileOAuthClaim(
        val transactionId: Long,
        val provider: SsoType,
        val purpose: MobileOAuthPurpose,
        val callbackUri: String,
        val authenticatedMemberId: Long?,
    )

    companion object {
        private const val APP_CALLBACK_URI = "dutypark://oauth/callback"
        private const val WEB_ACCOUNT_DELETION_CALLBACK_PATH = "/auth/account-deletion-oauth-callback"
        private val DEVELOPMENT_WEB_ORIGINS = setOf(
            "http://localhost:5173",
            "http://127.0.0.1:5173",
        )
        private val STATE_TTL: Duration = Duration.ofMinutes(5)
        private val EXCHANGE_CODE_TTL: Duration = Duration.ofMinutes(2)
    }

    private fun parseProvider(value: String): SsoType = runCatching {
        SsoType.valueOf(value.uppercase())
    }.getOrElse { throw IllegalArgumentException("auth.oauth.mobile.provider.invalid") }

    private fun parsePurpose(value: String): MobileOAuthPurpose = runCatching {
        MobileOAuthPurpose.valueOf(value.uppercase())
    }.getOrElse { throw IllegalArgumentException("auth.oauth.mobile.purpose.invalid") }

    private fun randomToken(): String = ByteArray(32).also(secureRandom::nextBytes)
        .let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }

    private fun verifyPkce(verifier: String, expectedChallenge: String): Boolean {
        val actual = Base64.getUrlEncoder().withoutPadding().encodeToString(
            MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII))
        )
        return MessageDigest.isEqual(
            actual.toByteArray(StandardCharsets.US_ASCII),
            expectedChallenge.toByteArray(StandardCharsets.US_ASCII),
        )
    }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}

data class MobileOAuthExchangeResult(
    val response: MobileOAuthExchangeResponse,
    val accessToken: String? = null,
    val refreshToken: String? = null,
)

/**
 * The production SPA is served from the same host as the API, so DOMAIN_NAME
 * also defines its fixed account-deletion OAuth callback without another env value.
 */
internal fun cookieDomainWebCallbackUri(cookieDomain: String): String? {
    if (cookieDomain.isBlank()) {
        return null
    }
    check(cookieDomain.none(Char::isWhitespace)) {
        "cookie.domain must be a plain DNS hostname"
    }
    val normalized = cookieDomain.trim('.').lowercase()
    val labels = normalized.split('.')
    val labelPattern = Regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
    val isPlainDnsHostname = normalized.length <= 253 && labels.size >= 2 &&
        labels.all { it.length <= 63 && labelPattern.matches(it) } &&
        labels.last().any(Char::isLetter)
    check(isPlainDnsHostname) {
        "cookie.domain must be a plain DNS hostname"
    }
    return "https://$normalized/auth/account-deletion-oauth-callback"
}
