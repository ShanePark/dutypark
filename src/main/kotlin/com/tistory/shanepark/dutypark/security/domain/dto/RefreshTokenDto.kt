package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import nl.basjes.parse.useragent.UserAgentAnalyzer
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
    var isCurrentLogin: Boolean? = null

    companion object {
        fun of(refreshToken: RefreshToken): RefreshTokenDto {
            return RefreshTokenDto(
                memberName = refreshToken.member.name,
                memberId = refreshToken.member.id ?: -1L,
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
            private val analyzer: UserAgentAnalyzer = UserAgentAnalyzer
                .newBuilder()
                .withFields(
                    "DeviceClass",
                    "DeviceName",
                    "OperatingSystemName",
                    "AgentName"
                )
                .withCache(1000)
                .build()

            fun of(userAgent: String?): UserAgent? {
                if (userAgent == null) return null
                val parsed = analyzer.parse(userAgent)
                return UserAgent(
                    os = parsed.getValue("OperatingSystemName") ?: "Unknown",
                    browser = parsed.getValue("AgentName") ?: "Unknown",
                    device = parsed.getValue("DeviceName") ?: "Unknown",
                )
            }
        }
    }
}
