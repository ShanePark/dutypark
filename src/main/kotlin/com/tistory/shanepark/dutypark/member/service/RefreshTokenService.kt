package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.slf4j.Logger
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.time.LocalDateTime

@Service
class RefreshTokenService(
    private val memberRepository: MemberRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val jwtConfig: JwtConfig,
) {
    private val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    @Scheduled(cron = "0 0 0 * * *")
    fun revokeExpiredRefreshTokens() {
        val expiredTokens = refreshTokenRepository.findAllByValidUntilIsBefore(LocalDateTime.now())
        log.info("Revoke expired refresh tokens. expiredTokensCount:${expiredTokens.size}")
        refreshTokenRepository.deleteAll(expiredTokens)
    }

    fun findRefreshTokens(memberId: Long, validOnly: Boolean): List<RefreshTokenDto> {
        val tokens = refreshTokenRepository
            .findAllByMemberIdOrderByLastUsedDesc(memberId)
            .filter { !validOnly || it.isValid() }

        return tokens.map { RefreshTokenDto.of(it) }
    }

    fun deleteRefreshToken(loginMember: LoginMember, id: Long) {
        val refreshToken = refreshTokenRepository.findById(id).orElseThrow()
        if (!loginMember.isAdmin && refreshToken.member.id != loginMember.id) {
            log.warn("No authority to delete refresh token. loginMemberId:${loginMember.id}, refreshTokenId:$id")
            throw DutyparkAuthException("No authority to delete refresh token.")
        }
        refreshTokenRepository.delete(refreshToken)
    }

    fun findByToken(refreshToken: String): RefreshToken? {
        return refreshTokenRepository.findByToken(refreshToken)
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

    fun revokeAllRefreshTokensByMember(member: Member) {
        val findAllByMember = refreshTokenRepository.findAllByMember(member)
        log.info("Revoked {} refresh tokens of member {}", findAllByMember.size, member.email)
        refreshTokenRepository.deleteAll(findAllByMember)
    }

}
