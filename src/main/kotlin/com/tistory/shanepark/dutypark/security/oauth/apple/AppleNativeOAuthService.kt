package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
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
    private val log = logger()

    @Transactional
    fun exchange(
        request: AppleNativeExchangeRequest,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        return exchangeForClient(
            request,
            loginMember,
            servletRequest,
            clientSecretFactory.clientId(),
            null,
        )
    }

    @Transactional
    internal fun exchangeForClient(
        request: AppleNativeExchangeRequest,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
        clientId: String,
        redirectUri: String?,
    ): MobileOAuthExchangeResult {
        val authenticated = authenticatedMember(request.purpose, loginMember)
        val clientSecret = clientSecretFactory.create(clientId)
        credentialService.ensureConfigured()
        val identity = tokenVerifier.verify(request.identityToken, request.nonce, clientId)
        val existingLoginMember = if (request.purpose == MobileOAuthPurpose.LOGIN) {
            lockExistingLoginMember(identity.subject)
        } else {
            null
        }
        consumeOnce(request.identityToken, identity.expiresAtEpochSecond)

        val tokenResponse = providerClient.exchange(
            request.authorizationCode,
            clientId,
            clientSecret,
            redirectUri,
        )
        val refreshToken = tokenResponse.refresh_token
            ?: throw AppleOAuthException("auth.apple.credential.invalid")

        if (request.purpose == MobileOAuthPurpose.LINK) {
            return try {
                verifyExchangedIdentity(tokenResponse, clientId, identity.subject)
                link(requireNotNull(authenticated), identity.subject, refreshToken, clientId)
            } catch (linkFailure: Exception) {
                compensateFailedLink(refreshToken, clientId, clientSecret, linkFailure)
            }
        }

        verifyExchangedIdentity(tokenResponse, clientId, identity.subject)

        return when (request.purpose) {
            MobileOAuthPurpose.LOGIN -> login(
                identity.subject,
                refreshToken,
                clientId,
                existingLoginMember,
                servletRequest,
            )
            MobileOAuthPurpose.LINK -> error("LINK returns before common exchange completion")
            MobileOAuthPurpose.DELETE_ACCOUNT -> reauthenticateDeletion(
                requireNotNull(authenticated), identity.subject, refreshToken, clientId
            )
        }
    }

    private fun login(
        subject: String,
        refreshToken: String,
        clientId: String,
        existingMember: Member?,
        request: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        credentialService.upsert(subject, refreshToken, clientId)
        if (existingMember == null) {
            val signup = signupRepository.save(MemberSsoRegister(SsoType.APPLE, subject))
            return MobileOAuthExchangeResult(MobileOAuthExchangeResponse(true, signupUuid = signup.uuid))
        }
        val tokens = authService.getTokenResponseByMemberId(requireNotNull(existingMember.id), request)
        return MobileOAuthExchangeResult(
            MobileOAuthExchangeResponse(false, expiresIn = tokens.expiresIn),
            tokens.accessToken,
            tokens.refreshToken,
        )
    }

    private fun lockExistingLoginMember(subject: String): Member? {
        val member = socialAccountService.findMemberByProviderAndSocialId(SsoType.APPLE, subject) ?: return null
        val memberId = member.id ?: throw AuthException("auth.token.memberNotFound")
        val locked = memberRepository.findMemberWithTeamForUpdate(memberId)
            .orElseThrow { AuthException("auth.token.memberNotFound") }
        if (locked.status != MemberStatus.ACTIVE) {
            throw AuthException("auth.account.inactive")
        }
        return locked
    }

    private fun link(
        memberId: Long,
        subject: String,
        refreshToken: String,
        clientId: String,
    ): MobileOAuthExchangeResult {
        val member = memberRepository.findById(memberId).orElseThrow { AuthException("auth.token.memberNotFound") }
        socialAccountService.link(member, SsoType.APPLE, subject)
        credentialService.upsert(subject, refreshToken, clientId)
        return MobileOAuthExchangeResult(MobileOAuthExchangeResponse(false))
    }

    private fun verifyExchangedIdentity(tokenResponse: AppleTokenResponse, clientId: String, subject: String) {
        val exchangeIdentityToken = tokenResponse.id_token
            ?: throw AppleOAuthException("auth.apple.credential.invalid")
        val exchangedIdentity = tokenVerifier.verify(exchangeIdentityToken, null, clientId, requireNonce = false)
        if (!constantTimeEquals(subject, exchangedIdentity.subject)) {
            throw AppleOAuthException("auth.apple.credential.invalid")
        }
    }

    private fun compensateFailedLink(
        refreshToken: String,
        clientId: String,
        clientSecret: String,
        linkFailure: Exception,
    ): Nothing {
        try {
            providerClient.revoke(refreshToken, clientId, clientSecret)
        } catch (revokeFailure: Exception) {
            linkFailure.addSuppressed(revokeFailure)
            try {
                credentialService.storeRevocationRetry(refreshToken, clientId)
                log.warn("Apple LINK credential revoke deferred for durable retry. clientId={}", clientId)
            } catch (retryPersistenceFailure: Exception) {
                linkFailure.addSuppressed(retryPersistenceFailure)
                log.error(
                    "Failed to persist Apple LINK credential revocation retry. clientId={}",
                    clientId,
                    retryPersistenceFailure,
                )
            }
        }
        throw linkFailure
    }

    private fun reauthenticateDeletion(
        memberId: Long,
        subject: String,
        refreshToken: String,
        clientId: String,
    ): MobileOAuthExchangeResult {
        val member = socialAccountService.findMemberByProviderAndSocialId(SsoType.APPLE, subject)
        if (member?.id != memberId) {
            throw AppleOAuthException("auth.apple.accountMismatch", 403)
        }
        credentialService.upsert(subject, refreshToken, clientId)
        val proof = reauthService.issue(memberId, ReauthPurpose.DELETE_ACCOUNT)
        return MobileOAuthExchangeResult(
            MobileOAuthExchangeResponse(false, expiresIn = proof.expiresIn, reauthProof = proof.reauthProof)
        )
    }

    private fun authenticatedMember(purpose: MobileOAuthPurpose, loginMember: LoginMember?): Long? {
        if (purpose == MobileOAuthPurpose.LOGIN) return null
        val member = loginMember ?: throw AuthException()
        if (member.isImpersonating) throw AuthException("auth.reauth.impersonationForbidden")
        if (purpose == MobileOAuthPurpose.LINK) {
            val locked = memberRepository.findMemberWithTeamForUpdate(member.id)
                .orElseThrow { AuthException("auth.token.memberNotFound") }
            if (locked.status != MemberStatus.ACTIVE) {
                throw AuthException("auth.account.inactive")
            }
        }
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
