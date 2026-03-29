package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpHeaders
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class AuthService(
    private val memberRepository: MemberRepository,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val memberManagerRepository: MemberManagerRepository,
    private val passwordEncoder: PasswordEncoder,
    private val refreshTokenService: RefreshTokenService,
    private val jwtProvider: JwtProvider,
    private val jwtConfig: JwtConfig,
    private val loginAttemptService: LoginAttemptService,
) {
    private val log = logger()

    companion object {
        private const val LOGIN_FAILED_MESSAGE = "auth.login.failed"
        private const val RATE_LIMIT_MESSAGE = "auth.login.rateLimited"
    }

    @Transactional(readOnly = true)
    fun validateToken(token: String): TokenStatus {
        return jwtProvider.validateToken(token)
    }

    @Transactional(readOnly = true)
    fun tokenToLoginMember(token: String): LoginMember {
        if (validateToken(token) == TokenStatus.VALID) {
            return jwtProvider.parseToken(token)
        }
        throw AuthException()
    }

    fun changePassword(param: PasswordChangeDto, byAdmin: Boolean = false) {
        val member = memberRepository.findById(param.memberId).orElseThrow {
            log.warn("Change password failed: member not exist, memberId={}", param.memberId)
            throw AuthException("auth.password.memberNotFound")
        }

        if (!byAdmin) {
            val passwordMatch = passwordEncoder.matches(param.currentPassword, member.password)
            if (!passwordMatch) {
                log.warn("Change password failed: password not match, memberId={}", param.memberId)
                throw AuthException("auth.password.currentMismatch")
            }
        }

        member.password = passwordEncoder.encode(param.newPassword)
        refreshTokenService.revokeAllRefreshTokensByMember(member)

        log.info("Member password changed: memberId={}", param.memberId)
    }

    fun getTokenResponse(login: LoginDto, req: HttpServletRequest): TokenResponse {
        val ipAddress = req.remoteAddr ?: "unknown"
        val email = login.email ?: throw AuthException(LOGIN_FAILED_MESSAGE)

        if (loginAttemptService.isBlocked(ipAddress, email)) {
            log.info("Login blocked due to rate limit: ip={}, email={}", ipAddress, email)
            throw RateLimitException(RATE_LIMIT_MESSAGE)
        }

        val member = memberRepository.findByEmail(email).orElse(null)

        if (member == null || !passwordEncoder.matches(login.password, member.password)) {
            loginAttemptService.recordFailedAttempt(ipAddress, email)
            log.info("Login failed: ip={}, email={}", ipAddress, email)
            throw AuthException(LOGIN_FAILED_MESSAGE)
        }

        loginAttemptService.recordSuccessfulAttempt(ipAddress, email)

        val jwt = jwtProvider.createToken(member)
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = member.id!!,
            remoteAddr = ipAddress,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    fun refreshAccessToken(refreshTokenValue: String, req: HttpServletRequest): TokenResponse {
        val refreshToken = refreshTokenService.findByToken(refreshTokenValue)
            ?: throw AuthException("auth.refresh.invalid")

        if (!refreshToken.isValid()) {
            throw AuthException("auth.refresh.expired")
        }

        val member = refreshToken.member
        val newJwt = jwtProvider.createToken(member)

        refreshToken.slideValidUntil(
            req.remoteAddr,
            req.getHeader(HttpHeaders.USER_AGENT),
            jwtConfig.refreshTokenValidityInDays
        )

        return TokenResponse(
            accessToken = newJwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    fun getTokenResponseByMemberId(memberId: Long, req: HttpServletRequest): TokenResponse {
        val member = memberRepository.findById(memberId).orElseThrow {
            log.warn("Token generation failed: member not exist, memberId={}", memberId)
            AuthException("auth.token.memberNotFound")
        }

        val jwt = jwtProvider.createToken(member)
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = memberId,
            remoteAddr = req.remoteAddr,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    fun impersonate(manager: LoginMember, targetMemberId: Long): String {
        if (manager.isImpersonating) {
            log.warn("Impersonation denied: manager {} already impersonating another account", manager.id)
            throw AuthException("auth.impersonation.alreadyImpersonating")
        }

        val managerEntity = memberRepository.findById(manager.id).orElseThrow {
            AuthException("auth.impersonation.managerNotFound")
        }

        val targetEntity = memberRepository.findById(targetMemberId).orElseThrow {
            AuthException("auth.impersonation.targetNotFound")
        }

        val isManager = memberManagerRepository.findAllByManagerAndManaged(managerEntity, targetEntity).isNotEmpty()
        if (!isManager) {
            log.warn("Impersonation denied: manager={} is not managing target={}", manager.id, targetMemberId)
            throw AuthException("auth.impersonation.forbidden")
        }

        log.info("Impersonation started: manager={} -> target={}", manager.id, targetMemberId)

        return jwtProvider.createImpersonationToken(targetEntity, manager.id)
    }

    fun restore(currentLogin: LoginMember, existingRefreshToken: String?, req: HttpServletRequest): TokenResponse {
        if (!currentLogin.isImpersonating) {
            throw AuthException("auth.restore.notImpersonating")
        }

        val originalMemberId = currentLogin.originalMemberId
            ?: throw AuthException("auth.restore.originalMissing")

        val originalMember = memberRepository.findById(originalMemberId).orElseThrow {
            AuthException("auth.restore.originalNotFound")
        }

        val jwt = jwtProvider.createToken(originalMember)

        val refreshToken = existingRefreshToken?.let { token ->
            refreshTokenService.findByToken(token)?.takeIf {
                it.member.id == originalMemberId && it.isValid()
            }?.also {
                it.slideValidUntil(
                    req.remoteAddr,
                    req.getHeader(HttpHeaders.USER_AGENT),
                    jwtConfig.refreshTokenValidityInDays
                )
            }
        } ?: refreshTokenService.createRefreshToken(
            memberId = originalMemberId,
            remoteAddr = req.remoteAddr,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )

        log.info("Impersonation ended: restored to={} from={}", originalMemberId, currentLogin.id)

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

}
