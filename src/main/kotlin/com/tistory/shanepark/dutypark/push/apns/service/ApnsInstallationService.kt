package com.tistory.shanepark.dutypark.push.apns.service

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
    fun register(loginMember: LoginMember, refreshTokenValue: String, deviceToken: String, sandbox: Boolean) {
        val normalizedToken = deviceToken.trim()
        val refreshToken = requireCurrentRefreshToken(loginMember, refreshTokenValue)
        val installation = apnsInstallationRepository.findByDeviceToken(normalizedToken)
            ?.apply {
                this.refreshToken = refreshToken
                this.sandbox = sandbox
            }
            ?: ApnsInstallation(refreshToken = refreshToken, deviceToken = normalizedToken, sandbox = sandbox)

        apnsInstallationRepository.save(installation)
    }

    fun unregister(loginMember: LoginMember, refreshTokenValue: String, deviceToken: String): Boolean {
        val refreshToken = requireCurrentRefreshToken(loginMember, refreshTokenValue)
        return apnsInstallationRepository.deleteByRefreshTokenIdAndDeviceToken(
            refreshToken.id!!,
            deviceToken.trim(),
        ) > 0
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
