package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.ClientType
import java.time.LocalDateTime

data class RefreshTokenDto(
    val memberName: String,
    val memberId: Long,
    val validUntil: LocalDateTime,
    val createdDate: LocalDateTime,
    val lastUsed: LocalDateTime?,
    val remoteAddr: String?,
    val id: Long,
    val userAgent: UserAgentInfo?,
    val clientType: ClientType = ClientType.BROWSER,
    val isCurrentLogin: Boolean? = null,
) {
    companion object {
        fun of(refreshToken: RefreshToken, isCurrentLogin: Boolean? = null): RefreshTokenDto {
            return RefreshTokenDto(
                memberName = refreshToken.member.name,
                memberId = refreshToken.member.id ?: -1L,
                validUntil = refreshToken.validUntil,
                createdDate = refreshToken.createdDate,
                lastUsed = refreshToken.lastUsed,
                remoteAddr = refreshToken.remoteAddr,
                id = refreshToken.id!!,
                userAgent = UserAgentInfo.fromStoredValue(refreshToken.userAgent),
                clientType = refreshToken.clientType,
                isCurrentLogin = isCurrentLogin,
            )
        }
    }
}
