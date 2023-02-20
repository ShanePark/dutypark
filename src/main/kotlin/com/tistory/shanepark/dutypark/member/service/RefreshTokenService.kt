package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import org.slf4j.Logger
import org.springframework.stereotype.Service

@Service
class RefreshTokenService(
    private val refreshTokenRepository: RefreshTokenRepository
) {
    private val log: Logger = org.slf4j.LoggerFactory.getLogger(this.javaClass)

    fun findAllRefreshTokensByMember(id: Long): List<RefreshTokenDto> {
        return refreshTokenRepository.findAllByMemberIdOrderByLastUsedDesc(id)
            .map { RefreshTokenDto.of(it) }
    }

    fun deleteRefreshToken(loginMember: LoginMember, id: Long) {
        val refreshToken = refreshTokenRepository.findById(id).orElseThrow()
        if (!loginMember.isAdmin && refreshToken.member.id != loginMember.id) {
            log.warn("No authority to delete refresh token. loginMemberId:${loginMember.id}, refreshTokenId:$id")
            throw AuthenticationException("No authority to delete refresh token.")
        }
        refreshTokenRepository.delete(refreshToken)
    }

}
