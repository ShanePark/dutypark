package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import jakarta.persistence.EntityManager
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpHeaders
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class AuthService(
    private val memberRepository: MemberRepository,
    private val memberManagerRepository: MemberManagerRepository,
    private val passwordEncoder: PasswordEncoder,
    private val refreshTokenService: RefreshTokenService,
    private val jwtProvider: JwtProvider,
    private val jwtConfig: JwtConfig,
    private val loginAttemptService: LoginAttemptService,
    private val entityManager: EntityManager,
    private val impersonationActorNameResolver: ImpersonationActorNameResolver =
        ImpersonationActorNameResolver(memberRepository),
) {
    private val log = logger()

    companion object {
        private const val LOGIN_FAILED_MESSAGE = "auth.login.failed"
        private const val RATE_LIMIT_MESSAGE = "auth.login.rateLimited"
        const val SUSPENDED_MESSAGE = "auth.account.suspended"
    }

    @Transactional(readOnly = true)
    fun validateToken(token: String): TokenStatus {
        return jwtProvider.validateToken(token)
    }

    @Transactional(readOnly = true)
    fun tokenToLoginMember(token: String): LoginMember {
        return authenticateToken(token) ?: throw AuthException()
    }

    @Transactional(readOnly = true)
    fun authenticateToken(token: String): LoginMember? {
        val loginMember = try {
            jwtProvider.parseToken(token)
        } catch (_: AuthException) {
            return null
        }
        // Only a JWT parsing failure permits trying another credential. Session and member
        // failures must propagate so a rejected bearer cannot fall back to a cookie.
        loginMember.sessionId?.let { sessionId ->
            val sessionOwnerId = if (loginMember.isImpersonating) {
                loginMember.originalMemberId ?: throw AuthException()
            } else {
                loginMember.id
            }
            if (!refreshTokenService.isSessionActive(sessionId, sessionOwnerId)) {
                throw AuthException()
            }
        }
        val member = memberRepository.findById(loginMember.id).orElseThrow {
            AuthException("auth.account.inactive")
        }
        ensureActive(member)
        if (!loginMember.isImpersonating) return loginMember

        val originalMemberName = loginMember.originalMemberName ?: loginMember.originalMemberId?.let { originalMemberId ->
            try {
                impersonationActorNameResolver.findName(originalMemberId)
            } catch (exception: RuntimeException) {
                log.warn(
                    "Impersonation actor name lookup failed {}",
                    auditContext(
                        mapOf(
                            "event" to "auth.impersonation.actor_name_lookup_failed",
                            "actor" to loginMember.toAuditActor(),
                            "target" to mapOf("type" to "Member", "id" to member.id, "name" to member.name),
                            "details" to mapOf(
                                "originalActorId" to originalMemberId,
                                "errorType" to exception.javaClass.simpleName,
                            ),
                            "reason" to "identity_enrichment_failed",
                        )
                    ),
                )
                null
            }
        }
        return loginMember.copy(originalMemberName = originalMemberName)
    }

    @Transactional(readOnly = true)
    fun verifyPasswordForReauth(memberId: Long, password: String) {
        val member = memberRepository.findById(memberId).orElseThrow {
            AuthException("auth.reauth.failed")
        }
        ensureActive(member, "auth.reauth.failed")
        if (member.password == null || !passwordEncoder.matches(password, member.password)) {
            throw AuthException("auth.reauth.failed")
        }
    }

    fun changePassword(
        param: PasswordChangeDto,
        byAdmin: Boolean = false,
        actor: LoginMember? = null,
    ) {
        val member = memberRepository.findById(param.memberId).orElseThrow {
            log.warn(
                "Password change denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "member.password.change_denied",
                        "actor" to actor?.toAuditActor(),
                        "target" to mapOf("type" to "Member", "id" to param.memberId),
                        "reason" to "member_not_found",
                    )
                ),
            )
            throw AuthException("auth.password.memberNotFound")
        }
        val auditActor = actor?.toAuditActor()
        val target = mapOf("type" to "Member", "id" to member.id, "name" to member.name)

        if (!byAdmin) {
            val passwordMatch = passwordEncoder.matches(param.currentPassword, member.password)
            if (!passwordMatch) {
                log.warn(
                    "Password change denied {}",
                    auditContext(
                        linkedMapOf(
                            "event" to "member.password.change_denied",
                            "actor" to auditActor,
                            "target" to target,
                            "reason" to "current_password_mismatch",
                        )
                    ),
                )
                throw AuthException("auth.password.currentMismatch")
            }
        }

        member.password = passwordEncoder.encode(param.newPassword)
        refreshTokenService.revokeAllRefreshTokensByMember(
            member = member,
            actor = actor,
            reason = "password_changed",
        )
        log.auditEventAfterCommit(
            event = "member.password.changed",
            actor = auditActor,
            target = target,
            details = mapOf("credentialChanged" to true, "changedFields" to listOf("password"), "byAdmin" to byAdmin),
        )
    }

    fun getTokenResponse(login: LoginDto, req: HttpServletRequest): TokenResponse {
        val ipAddress = req.remoteAddr ?: "unknown"
        val email = login.email ?: throw AuthException(LOGIN_FAILED_MESSAGE)

        if (loginAttemptService.isBlocked(ipAddress, email)) {
            log.info(
                "Login denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "auth.login.denied",
                        "request" to mapOf("method" to req.method, "path" to req.requestURI),
                        "ipAddress" to ipAddress,
                        "status" to 429,
                        "reason" to "rate_limited",
                    )
                ),
            )
            throw RateLimitException(RATE_LIMIT_MESSAGE)
        }

        val member = memberRepository.findByEmail(email).orElse(null)

        if (member == null || !passwordEncoder.matches(login.password, member.password)) {
            loginAttemptService.recordFailedAttempt(ipAddress, email)
            log.info(
                "Login denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "auth.login.denied",
                        "request" to mapOf("method" to req.method, "path" to req.requestURI),
                        "ipAddress" to ipAddress,
                        "status" to 401,
                        "reason" to "invalid_credentials",
                        "target" to member?.let {
                            mapOf("type" to "Member", "id" to it.id, "name" to it.name)
                        },
                    )
                ),
            )
            throw AuthException(LOGIN_FAILED_MESSAGE)
        }

        // Lock only after the password matched, so failed logins do not contend on the account.
        // Suspension uses the same row lock and therefore cannot revoke sessions before this
        // successful login finishes creating its refresh token.
        val lockedMember = memberRepository.findMemberWithTeamForUpdate(requireNotNull(member.id)).orElseThrow {
            AuthException(LOGIN_FAILED_MESSAGE)
        }
        // The password lookup already put this entity in the persistence context. Refresh after
        // acquiring the row lock so a suspension committed between the two reads is visible.
        entityManager.refresh(lockedMember)
        ensureActive(lockedMember, LOGIN_FAILED_MESSAGE)

        loginAttemptService.recordSuccessfulAttempt(ipAddress, email)

        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = requireNotNull(lockedMember.id),
            remoteAddr = ipAddress,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )
        val jwt = jwtProvider.createToken(lockedMember, requireNotNull(refreshToken.id))

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
        ensureActive(member)
        val newJwt = jwtProvider.createToken(member, requireNotNull(refreshToken.id))

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
            log.warn(
                "Token generation denied {}",
                auditContext(
                    mapOf(
                        "event" to "auth.token.generation_denied",
                        "target" to mapOf("type" to "Member", "id" to memberId),
                        "reason" to "member_not_found",
                    )
                ),
            )
            AuthException("auth.token.memberNotFound")
        }
        ensureActive(member)

        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = memberId,
            remoteAddr = req.remoteAddr,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )
        val jwt = jwtProvider.createToken(member, requireNotNull(refreshToken.id))

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    fun impersonate(
        manager: LoginMember,
        targetMemberId: Long,
        legacyRefreshToken: String? = null,
    ): String {
        if (manager.isImpersonating) {
            logImpersonationDenied(
                actor = manager.toAuditActor(),
                target = mapOf("type" to "Member", "id" to targetMemberId),
                reason = "manager_already_impersonating",
            )
            throw AuthException("auth.impersonation.alreadyImpersonating")
        }

        val managerEntity = memberRepository.findById(manager.id).orElse(null) ?: run {
            logImpersonationDenied(
                actor = manager.toAuditActor(),
                target = mapOf("type" to "Member", "id" to targetMemberId),
                reason = "manager_not_found",
            )
            throw AuthException("auth.impersonation.managerNotFound")
        }
        try {
            ensureActive(managerEntity)
        } catch (exception: AuthException) {
            logImpersonationDenied(
                actor = manager.toAuditActor(),
                target = mapOf("type" to "Member", "id" to targetMemberId),
                reason = "manager_inactive",
                status = managerEntity.status,
            )
            throw exception
        }

        val targetEntity = memberRepository.findById(targetMemberId).orElse(null) ?: run {
            logImpersonationDenied(
                actor = manager.toAuditActor(),
                target = mapOf("type" to "Member", "id" to targetMemberId),
                reason = "target_not_found",
            )
            throw AuthException("auth.impersonation.targetNotFound")
        }
        try {
            ensureActive(targetEntity)
        } catch (exception: AuthException) {
            logImpersonationDenied(
                actor = manager.toAuditActor(),
                target = mapOf("type" to "Member", "id" to targetEntity.id, "name" to targetEntity.name),
                reason = "target_inactive",
                status = targetEntity.status,
            )
            throw exception
        }

        val isManager = memberManagerRepository.findAllByManagerAndManaged(managerEntity, targetEntity).isNotEmpty()
        if (!isManager) {
            logImpersonationDenied(
                actor = manager.toAuditActor(),
                target = mapOf("type" to "Member", "id" to targetEntity.id, "name" to targetEntity.name),
                reason = "not_managed",
            )
            throw AuthException("auth.impersonation.forbidden")
        }

        val sessionId = manager.sessionId ?: legacyRefreshToken?.let(refreshTokenService::findByToken)
            ?.takeIf { it.member.id == manager.id && it.isValid() }
            ?.id
            ?: run {
                logImpersonationDenied(
                    actor = manager.toAuditActor(),
                    target = mapOf("type" to "Member", "id" to targetEntity.id, "name" to targetEntity.name),
                    reason = "session_invalid",
                )
                throw AuthException("auth.impersonation.sessionInvalid")
            }
        val impersonationToken = jwtProvider.createImpersonationToken(targetEntity, manager.id, sessionId)
        log.auditEventAfterCommit(
            event = "auth.impersonation.started",
            actor = manager.toAuditActor(),
            target = mapOf("type" to "Member", "id" to targetEntity.id, "name" to targetEntity.name),
            details = mapOf("sessionId" to sessionId),
        )
        return impersonationToken
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
        ensureActive(originalMember)

        val refreshToken = existingRefreshToken?.let { token ->
            refreshTokenService.findByToken(token)?.takeIf {
                (currentLogin.sessionId == null || it.id == currentLogin.sessionId) &&
                    it.member.id == originalMemberId && it.isValid()
            }?.also {
                it.slideValidUntil(
                    req.remoteAddr,
                    req.getHeader(HttpHeaders.USER_AGENT),
                    jwtConfig.refreshTokenValidityInDays
                )
            }
        } ?: throw AuthException("auth.restore.sessionInvalid")
        val jwt = jwtProvider.createToken(originalMember, requireNotNull(refreshToken.id))

        log.auditEventAfterCommit(
            event = "auth.impersonation.ended",
            actor = originalMember.toAuditActor(),
            target = mapOf("type" to "Member", "id" to currentLogin.id, "name" to currentLogin.name),
            details = mapOf("sessionId" to refreshToken.id),
        )

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    private fun ensureActive(member: Member, code: String = "auth.account.inactive") {
        if (member.status == MemberStatus.SUSPENDED) {
            throw AuthException(SUSPENDED_MESSAGE)
        }
        if (member.status != MemberStatus.ACTIVE) {
            throw AuthException(code)
        }
    }

    private fun logImpersonationDenied(
        actor: com.tistory.shanepark.dutypark.common.logging.AuditActor,
        target: Map<String, Any?>,
        reason: String,
        status: MemberStatus? = null,
    ) {
        log.warn(
            "Impersonation denied {}",
            auditContext(
                linkedMapOf<String, Any?>(
                    "event" to "auth.impersonation.denied",
                    "actor" to actor,
                    "target" to target,
                    "reason" to reason,
                ).apply { status?.let { put("status", it) } }
            ),
        )
    }

}
