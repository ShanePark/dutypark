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
import java.time.Instant
import java.util.Base64

@Service
class MobileOAuthService(
    private val transactionRepository: MobileOAuthTransactionRepository,
    private val providerGateway: MobileOAuthProviderGateway,
    private val memberSocialAccountService: MemberSocialAccountService,
    private val memberRepository: MemberRepository,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val authService: AuthService,
    private val clock: Clock,
    transactionManager: PlatformTransactionManager,
    @param:Value("\${oauth.kakao.rest-api-key}") private val kakaoClientId: String,
    @param:Value("\${oauth.naver.client-id}") private val naverClientId: String,
) {
    private val log = logger()
    private val secureRandom = SecureRandom()
    private val callbackTransaction = TransactionTemplate(transactionManager)

    @Transactional
    fun authorize(
        request: MobileOAuthAuthorizeRequest,
        loginMember: LoginMember?,
        mobileOAuthBaseUrl: String,
    ): MobileOAuthAuthorizeResponse {
        val provider = parseProvider(request.provider)
        val purpose = parsePurpose(request.purpose)
        val linkMemberId = if (purpose == MobileOAuthPurpose.LINK) {
            loginMember?.id ?: throw AuthException()
        } else {
            null
        }
        require(request.callbackUri == APP_CALLBACK_URI) {
            "auth.oauth.mobile.callback.notAllowed"
        }
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
                linkMemberId = linkMemberId,
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
                linkMemberId = transaction.linkMemberId,
            )
        })
    }

    private fun finalizeCallback(claim: MobileOAuthClaim, socialId: String): URI {
        return requireNotNull(callbackTransaction.execute {
            if (claim.purpose == MobileOAuthPurpose.LINK) {
                val member = memberRepository.findById(requireNotNull(claim.linkMemberId)).orElseThrow {
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
            if (member != null) {
                transaction.completeForMember(sha256Hex(exchangeCode), exchangeExpiresAt, member.id!!)
            } else {
                val signup = memberSsoRegisterRepository.save(MemberSsoRegister(claim.provider, socialId))
                transaction.completeForSignup(sha256Hex(exchangeCode), exchangeExpiresAt, signup.uuid)
            }
            callbackUri(claim.callbackUri, "code", exchangeCode)
        })
    }

    private fun providerCallbackUri(mobileOAuthBaseUrl: String, provider: SsoType): String {
        return "${mobileOAuthBaseUrl.trimEnd('/')}/callback/${provider.name.lowercase()}"
    }

    private data class MobileOAuthClaim(
        val transactionId: Long,
        val provider: SsoType,
        val purpose: MobileOAuthPurpose,
        val callbackUri: String,
        val linkMemberId: Long?,
    )

    companion object {
        private const val APP_CALLBACK_URI = "dutypark://oauth/callback"
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
