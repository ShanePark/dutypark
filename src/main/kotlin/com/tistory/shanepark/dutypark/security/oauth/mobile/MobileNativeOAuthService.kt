package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.web.OAuthAuthorizeRateLimitService
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import jakarta.persistence.EntityManager
import org.springframework.dao.TransientDataAccessException
import org.springframework.stereotype.Service
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.support.TransactionTemplate

@Service
class MobileNativeOAuthService(
    private val providerGateway: MobileOAuthProviderGateway,
    private val memberSocialAccountService: MemberSocialAccountService,
    private val memberRepository: MemberRepository,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val authService: AuthService,
    private val authorizeRateLimitService: OAuthAuthorizeRateLimitService,
    private val entityManager: EntityManager,
    transactionManager: PlatformTransactionManager,
) {
    private val databaseTransaction = TransactionTemplate(transactionManager)

    fun exchange(
        request: MobileOAuthNativeExchangeRequest,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        val provider = parseProvider(request.provider)
        val purpose = parsePurpose(request.purpose)
        val authenticatedMember = when (purpose) {
            MobileOAuthPurpose.LOGIN -> null
            MobileOAuthPurpose.LINK -> requireAuthenticatedMember(loginMember)
            MobileOAuthPurpose.DELETE_ACCOUNT -> throw IllegalArgumentException("auth.oauth.mobile.purpose.invalid")
        }

        providerGateway.validateNativeCredentialShape(
            provider = provider,
            accessToken = request.accessToken,
            refreshToken = request.refreshToken,
        )
        acquireRateLimit(servletRequest)

        val socialId = providerGateway.getNativeSocialId(
            provider = provider,
            accessToken = request.accessToken,
            refreshToken = request.refreshToken,
        )

        return requireNotNull(databaseTransaction.execute {
            completeExchange(
                provider = provider,
                purpose = purpose,
                socialId = socialId,
                authenticatedMemberId = authenticatedMember?.id,
                servletRequest = servletRequest,
            )
        })
    }

    @Transactional(readOnly = true)
    fun capabilities(): MobileOAuthNativeCapabilitiesResponse =
        MobileOAuthNativeCapabilitiesResponse(providerGateway.nativeCapabilities())

    private fun requireAuthenticatedMember(loginMember: LoginMember?): LoginMember {
        val authenticated = loginMember ?: throw AuthException()
        if (authenticated.isImpersonating) {
            throw AuthException("auth.reauth.impersonationForbidden")
        }
        return authenticated
    }

    private fun completeExchange(
        provider: SsoType,
        purpose: MobileOAuthPurpose,
        socialId: String,
        authenticatedMemberId: Long?,
        servletRequest: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        if (purpose == MobileOAuthPurpose.LINK) {
            val member = lockActiveMember(authenticatedMemberId)
            memberSocialAccountService.link(member, provider, socialId)
            return MobileOAuthExchangeResult(MobileOAuthExchangeResponse(signupRequired = false))
        }

        val existingMember = memberSocialAccountService.findMemberByProviderAndSocialId(provider, socialId)
        if (existingMember != null) {
            val lockedMember = lockActiveMember(existingMember.id)
            val tokens = authService.getTokenResponseByMemberId(requireNotNull(lockedMember.id), servletRequest)
            return MobileOAuthExchangeResult(
                response = MobileOAuthExchangeResponse(false, expiresIn = tokens.expiresIn),
                accessToken = tokens.accessToken,
                refreshToken = tokens.refreshToken,
            )
        }

        val signup = memberSsoRegisterRepository.save(MemberSsoRegister(provider, socialId))
        return MobileOAuthExchangeResult(
            response = MobileOAuthExchangeResponse(true, signupUuid = signup.uuid),
        )
    }

    private fun acquireRateLimit(servletRequest: HttpServletRequest) {
        val acquired = try {
            authorizeRateLimitService.acquire(servletRequest.remoteAddr ?: "unknown")
        } catch (_: TransientDataAccessException) {
            false
        }
        if (!acquired) {
            throw com.tistory.shanepark.dutypark.common.exceptions.RateLimitException()
        }
    }

    private fun lockActiveMember(memberId: Long?): Member {
        val member = memberRepository.findMemberWithTeamForUpdate(memberId ?: throw AuthException())
            .orElseThrow { AuthException("auth.token.memberNotFound") }
        // The provider lookup can have loaded this member before the row lock was acquired.
        // Refresh after locking so a concurrent suspension is visible before linking or issuing tokens.
        entityManager.refresh(member)
        if (member.status != MemberStatus.ACTIVE) {
            throw AuthException("auth.account.inactive")
        }
        return member
    }

    private fun parseProvider(value: String): SsoType = when (value.uppercase()) {
        SsoType.KAKAO.name -> SsoType.KAKAO
        SsoType.NAVER.name -> SsoType.NAVER
        else -> throw IllegalArgumentException("auth.oauth.mobile.provider.invalid")
    }

    private fun parsePurpose(value: String): MobileOAuthPurpose = runCatching {
        MobileOAuthPurpose.valueOf(value.uppercase())
    }.getOrElse { throw IllegalArgumentException("auth.oauth.mobile.purpose.invalid") }
        .also {
            if (it == MobileOAuthPurpose.DELETE_ACCOUNT) {
                throw IllegalArgumentException("auth.oauth.mobile.purpose.invalid")
            }
        }
}
