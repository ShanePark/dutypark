package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.time.LocalDateTime

@Service
class RefreshTokenService(
    private val memberRepository: MemberRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val jwtConfig: JwtConfig,
) {
    private val log = logger()

    @Scheduled(cron = "0 0 0 * * *")
    fun revokeExpiredRefreshTokens() {
        val expiredTokens = refreshTokenRepository.findAllByValidUntilIsBefore(LocalDateTime.now())
        if (expiredTokens.isEmpty()) return
        refreshTokenRepository.deleteAll(expiredTokens)
        log.auditEventAfterCommit(
            event = "auth.refresh_tokens.expired_revoked",
            actor = AuditActor(id = null, name = "system"),
            target = mapOf("type" to "RefreshToken"),
            details = mapOf("count" to expiredTokens.size, "reason" to "expired"),
        )
    }

    fun findRefreshTokens(
        memberId: Long,
        validOnly: Boolean,
        currentToken: String? = null,
    ): List<RefreshTokenDto> {
        val tokens = refreshTokenRepository
            .findAllByMemberIdOrderByLastUsedDesc(memberId)
            .filter { !validOnly || it.isValid() }

        return tokens.map { refreshToken ->
            RefreshTokenDto.of(
                refreshToken = refreshToken,
                isCurrentLogin = true.takeIf {
                    currentToken != null && refreshToken.token == currentToken
                },
            )
        }
    }

    fun deleteRefreshToken(loginMember: LoginMember, id: Long, currentToken: String? = null): Boolean {
        val refreshToken = refreshTokenRepository.findById(id).orElse(null) ?: run {
            log.warn(
                "Refresh token deletion denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "auth.refresh_token.delete_denied",
                        "actor" to loginMember.toAuditActor(),
                        "target" to mapOf("refreshTokenId" to id),
                        "reason" to "token_not_found",
                    )
                ),
            )
            throw NoSuchElementException()
        }
        if (!loginMember.isAdmin && refreshToken.member.id != loginMember.id) {
            log.warn(
                "Refresh token deletion denied {}",
                auditContext(
                    linkedMapOf(
                        "event" to "auth.refresh_token.delete_denied",
                        "actor" to loginMember.toAuditActor(),
                        "target" to mapOf("type" to "Member", "id" to refreshToken.member.id, "refreshTokenId" to id),
                        "reason" to "not_token_owner",
                    )
                ),
            )
            throw AuthException("auth.refreshToken.delete.forbidden")
        }
        val deletedCurrentToken = currentToken != null && refreshToken.token == currentToken
        refreshTokenRepository.delete(refreshToken)
        log.auditEventAfterCommit(
            event = "auth.refresh_token.deleted",
            actor = loginMember.toAuditActor(),
            target = mapOf("type" to "Member", "id" to refreshToken.member.id),
            details = mapOf(
                "refreshTokenId" to id,
                "currentSession" to deletedCurrentToken,
                "reason" to if (loginMember.isAdmin && refreshToken.member.id != loginMember.id) {
                    "admin_revoked_session"
                } else {
                    "member_removed_session"
                },
            ),
        )
        return deletedCurrentToken
    }

    fun findByToken(refreshToken: String): RefreshToken? {
        return refreshTokenRepository.findByToken(refreshToken)
    }

    fun isSessionActive(sessionId: Long, memberId: Long): Boolean {
        return refreshTokenRepository.existsByIdAndMemberIdAndValidUntilAfter(
            id = sessionId,
            memberId = memberId,
            now = LocalDateTime.now(),
        )
    }

    fun deleteByToken(token: String): Boolean {
        val refreshToken = refreshTokenRepository.findByToken(token) ?: return false
        refreshTokenRepository.delete(refreshToken)
        log.auditEventAfterCommit(
            event = "auth.refresh_token.deleted",
            actor = refreshToken.member.toAuditActor(),
            target = memberTarget(refreshToken.member),
            details = mapOf(
                "refreshTokenId" to refreshToken.id,
                "reason" to "logout",
            ),
        )
        return true
    }

    fun createRefreshToken(memberId: Long, remoteAddr: String?, userAgent: String?): RefreshToken {
        val member = memberRepository.findById(memberId).orElseThrow()
        val refreshToken = RefreshToken(
            member = member,
            validUntil = LocalDateTime.now().plusDays(jwtConfig.refreshTokenValidityInDays),
            remoteAddr = remoteAddr,
            userAgent = userAgent,
        )
        return refreshTokenRepository.save(refreshToken)
    }

    fun findAllWithMemberOrderByLastUsedDesc(): List<RefreshTokenDto> {
        return refreshTokenRepository.findAllWithMemberOrderByLastUsedDesc()
            .filter { it.isValid() }
            .map { RefreshTokenDto.of(it) }
    }

    fun revokeAllRefreshTokensByMember(
        member: Member,
        actor: LoginMember? = null,
        reason: String = "security_action",
    ) {
        val findAllByMember = refreshTokenRepository.findAllByMember(member)
        refreshTokenRepository.deleteAll(findAllByMember)
        if (findAllByMember.isNotEmpty()) {
            log.auditEventAfterCommit(
                event = "auth.refresh_tokens.revoked_all",
                actor = actor?.toAuditActor(),
                target = memberTarget(member),
                details = mapOf("count" to findAllByMember.size, "reason" to reason),
            )
        }
    }

    fun deleteOtherRefreshTokens(memberId: Long, currentToken: String, actor: LoginMember? = null): Int {
        val tokens = refreshTokenRepository.findAllByMemberIdOrderByLastUsedDesc(memberId)
        val tokensToDelete = tokens.filter { it.token != currentToken }
        refreshTokenRepository.deleteAll(tokensToDelete)
        if (tokensToDelete.isNotEmpty()) {
            val member = tokensToDelete.first().member
            log.auditEventAfterCommit(
                event = "auth.refresh_tokens.deleted_other",
                actor = actor?.toAuditActor(),
                target = memberTarget(member),
                details = mapOf("count" to tokensToDelete.size, "reason" to "other_sessions_removed"),
            )
        }
        return tokensToDelete.size
    }

    private fun memberTarget(member: Member): Map<String, Any?> =
        mapOf("type" to "Member", "id" to member.id, "name" to member.name)

}
