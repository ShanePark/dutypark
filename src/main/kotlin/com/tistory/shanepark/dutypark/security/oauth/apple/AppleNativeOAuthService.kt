package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResult
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.nio.charset.StandardCharsets
import java.security.MessageDigest

@Service
class AppleNativeOAuthService(
    private val tokenVerifier: AppleIdentityTokenVerifier,
    private val providerClient: AppleProviderClient,
    private val clientSecretFactory: AppleClientSecretFactory,
    private val replayService: AppleIdentityTokenReplayService,
    private val credentialService: AppleCredentialService,
    private val socialAccountService: MemberSocialAccountService,
    private val memberRepository: MemberRepository,
    private val signupRepository: MemberSsoRegisterRepository,
    private val authService: AuthService,
    private val reauthService: ReauthService,
) {
    @Transactional
    fun exchange(
        request: AppleNativeExchangeRequest,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        val authenticated = authenticatedMember(request.purpose, loginMember)
        val clientId = clientSecretFactory.clientId()
        val clientSecret = clientSecretFactory.create()
        credentialService.ensureConfigured()
        val identity = tokenVerifier.verify(request.identityToken, request.nonce)
        consumeOnce(request.identityToken, identity.expiresAtEpochSecond)

        val tokenResponse = providerClient.exchange(
            request.authorizationCode,
            clientId,
            clientSecret,
        )
        val refreshToken = tokenResponse.refresh_token
            ?: throw AppleOAuthException("auth.apple.credential.invalid")
        val exchangeIdentityToken = tokenResponse.id_token
            ?: throw AppleOAuthException("auth.apple.credential.invalid")
        val exchangedIdentity = tokenVerifier.verify(exchangeIdentityToken, null, requireNonce = false)
        if (!constantTimeEquals(identity.subject, exchangedIdentity.subject)) {
            throw AppleOAuthException("auth.apple.credential.invalid")
        }

        return when (request.purpose) {
            MobileOAuthPurpose.LOGIN -> login(identity.subject, refreshToken, servletRequest)
            MobileOAuthPurpose.LINK -> link(requireNotNull(authenticated), identity.subject, refreshToken)
            MobileOAuthPurpose.DELETE_ACCOUNT -> reauthenticateDeletion(
                requireNotNull(authenticated), identity.subject, refreshToken
            )
        }
    }

    private fun login(subject: String, refreshToken: String, request: HttpServletRequest): MobileOAuthExchangeResult {
        credentialService.upsert(subject, refreshToken)
        val member = socialAccountService.findMemberByProviderAndSocialId(SsoType.APPLE, subject)
        if (member == null) {
            val signup = signupRepository.save(MemberSsoRegister(SsoType.APPLE, subject))
            return MobileOAuthExchangeResult(MobileOAuthExchangeResponse(true, signupUuid = signup.uuid))
        }
        val tokens = authService.getTokenResponseByMemberId(requireNotNull(member.id), request)
        return MobileOAuthExchangeResult(
            MobileOAuthExchangeResponse(false, expiresIn = tokens.expiresIn),
            tokens.accessToken,
            tokens.refreshToken,
        )
    }

    private fun link(memberId: Long, subject: String, refreshToken: String): MobileOAuthExchangeResult {
        val member = memberRepository.findById(memberId).orElseThrow { AuthException("auth.token.memberNotFound") }
        socialAccountService.link(member, SsoType.APPLE, subject)
        credentialService.upsert(subject, refreshToken)
        return MobileOAuthExchangeResult(MobileOAuthExchangeResponse(false))
    }

    private fun reauthenticateDeletion(
        memberId: Long,
        subject: String,
        refreshToken: String,
    ): MobileOAuthExchangeResult {
        val member = socialAccountService.findMemberByProviderAndSocialId(SsoType.APPLE, subject)
        if (member?.id != memberId) {
            throw AppleOAuthException("auth.apple.accountMismatch", 403)
        }
        credentialService.upsert(subject, refreshToken)
        val proof = reauthService.issue(memberId, ReauthPurpose.DELETE_ACCOUNT)
        return MobileOAuthExchangeResult(
            MobileOAuthExchangeResponse(false, expiresIn = proof.expiresIn, reauthProof = proof.reauthProof)
        )
    }

    private fun authenticatedMember(purpose: MobileOAuthPurpose, loginMember: LoginMember?): Long? {
        if (purpose == MobileOAuthPurpose.LOGIN) return null
        val member = loginMember ?: throw AuthException()
        if (member.isImpersonating) throw AuthException("auth.reauth.impersonationForbidden")
        return member.id
    }

    private fun consumeOnce(token: String, expiresAtEpochSecond: Long) {
        val hash = sha256Hex(token)
        replayService.consume(hash, expiresAtEpochSecond)
    }

    private fun constantTimeEquals(left: String, right: String): Boolean = MessageDigest.isEqual(
        left.toByteArray(StandardCharsets.UTF_8),
        right.toByteArray(StandardCharsets.UTF_8),
    )

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}
