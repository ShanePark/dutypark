package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import ua_parser.Parser
import java.time.LocalDateTime

data class RefreshTokenDto(
    val memberName: String,
    val memberId: Long,
    val validUntil: LocalDateTime,
    val lastUsed: LocalDateTime?,
    val remoteAddr: String?,
    val id: Long,
    val token: String,
    val userAgent: UserAgent?,
) {
    companion object {
        fun of(refreshToken: RefreshToken): RefreshTokenDto {
            return RefreshTokenDto(
                memberName = refreshToken.member.name,
                memberId = refreshToken.member.id!!,
                validUntil = refreshToken.validUntil,
                lastUsed = refreshToken.lastUsed,
                remoteAddr = refreshToken.remoteAddr,
                id = refreshToken.id!!,
                token = refreshToken.token,
                userAgent = UserAgent.of(refreshToken.userAgent),
            )
        }
    }

    data class UserAgent(
        val os: String,
        val browser: String,
        val device: String,
    ) {

        companion object {
            private val parser = Parser()

            fun of(userAgent: String?): UserAgent? {
                if (userAgent == null) return null
                val client = parser.parse(userAgent)
                return UserAgent(
                    os = client.os.family,
                    browser = client.userAgent.family,
                    device = client.device.family,
                )
            }
        }
    }
}
