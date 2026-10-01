package com.tistory.shanepark.dutypark.push.apns.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class ApnsInstallationService(
    private val apnsInstallationRepository: ApnsInstallationRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
) {
    private val log = logger()

    fun register(loginMember: LoginMember, refreshTokenValue: String, deviceToken: String, sandbox: Boolean) {
        val normalizedToken = deviceToken.trim()
        val refreshToken = requireCurrentRefreshToken(loginMember, refreshTokenValue)
        val existing = apnsInstallationRepository.findByDeviceToken(normalizedToken)
        val before = existing?.let { mapOf("refreshTokenId" to it.refreshToken.id, "sandbox" to it.sandbox) }
        val installation = existing?.apply {
            this.refreshToken = refreshToken
            this.sandbox = sandbox
        } ?: ApnsInstallation(refreshToken = refreshToken, deviceToken = normalizedToken, sandbox = sandbox)

        apnsInstallationRepository.save(installation)
        val target = mapOf("installationId" to installation.id, "memberId" to refreshToken.member.id)
        val after = mapOf("refreshTokenId" to refreshToken.id, "sandbox" to sandbox)
        if (before == null) {
            log.auditEventAfterCommit("apns_installation_registered", loginMember.toAuditActor(), target, after)
        } else {
            log.auditChangeAfterCommit("apns_installation_updated", loginMember.toAuditActor(), target, before, after)
        }
    }

    fun unregister(loginMember: LoginMember, refreshTokenValue: String, deviceToken: String): Boolean {
        val refreshToken = requireCurrentRefreshToken(loginMember, refreshTokenValue)
        val deletedCount = apnsInstallationRepository.deleteByRefreshTokenIdAndDeviceToken(
            refreshToken.id!!,
            deviceToken.trim(),
        )
        if (deletedCount > 0) {
            log.auditEventAfterCommit(
                "apns_installation_removed", loginMember.toAuditActor(),
                mapOf("refreshTokenId" to refreshToken.id, "memberId" to refreshToken.member.id),
                mapOf("deletedCount" to deletedCount),
            )
        }
        return deletedCount > 0
    }

    private fun requireCurrentRefreshToken(loginMember: LoginMember, tokenValue: String): RefreshToken {
        val refreshToken = refreshTokenRepository.findByToken(tokenValue)
            ?.takeIf(RefreshToken::isValid)
            ?: throw AuthException("auth.refresh.invalid")
        val sessionOwnerId = if (loginMember.isImpersonating) {
            loginMember.originalMemberId
        } else {
            loginMember.id
        }
        if (sessionOwnerId == null || refreshToken.member.id != sessionOwnerId) {
            throw AuthException("auth.refresh.invalid")
        }
        return refreshToken
    }
}
