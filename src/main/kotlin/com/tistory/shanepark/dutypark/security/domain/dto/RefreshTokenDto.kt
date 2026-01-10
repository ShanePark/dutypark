package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import java.time.LocalDateTime

data class RefreshTokenDto(
    val memberName: String,
    val memberId: Long,
    val validUntil: LocalDateTime,
    val createdDate: LocalDateTime,
    val lastUsed: LocalDateTime?,
    val remoteAddr: String?,
    val id: Long,
    val token: String,
    val userAgent: UserAgentInfo?,
) {
    var isCurrentLogin: Boolean? = null

    companion object {
        fun of(refreshToken: RefreshToken): RefreshTokenDto {
            return RefreshTokenDto(
                memberName = refreshToken.member.name,
                memberId = refreshToken.member.id ?: -1L,
                validUntil = refreshToken.validUntil,
                createdDate = refreshToken.createdDate,
                lastUsed = refreshToken.lastUsed,
                remoteAddr = refreshToken.remoteAddr,
                id = refreshToken.id!!,
                token = refreshToken.token,
                userAgent = UserAgentInfo.fromJson(refreshToken.userAgent),
            )
        }
    }
}
