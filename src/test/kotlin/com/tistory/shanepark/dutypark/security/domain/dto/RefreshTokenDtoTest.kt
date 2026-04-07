package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenDtoTest {

    private val chromeUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    @Test
    fun `of parses raw user agent values`() {
        val refreshToken = refreshToken(userAgent = chromeUserAgent)

        val result = RefreshTokenDto.of(refreshToken)

        assertThat(result.userAgent?.browser).isEqualTo("Chrome")
        assertThat(result.userAgent?.os).isEqualTo("Windows NT")
    }

    @Test
    fun `of keeps supporting legacy json user agent values`() {
        val legacyJson = UserAgentInfo.parse(chromeUserAgent)?.toJson()
        val refreshToken = refreshToken(userAgent = legacyJson)

        val result = RefreshTokenDto.of(refreshToken)

        assertThat(result.userAgent?.browser).isEqualTo("Chrome")
        assertThat(result.userAgent?.os).isEqualTo("Windows NT")
    }

    private fun refreshToken(userAgent: String?): RefreshToken {
        val member = Member(name = "tester", email = "tester@duty.park", password = "secret")
        val memberIdField = Member::class.java.getDeclaredField("id")
        memberIdField.isAccessible = true
        memberIdField.set(member, 1L)

        val refreshToken = RefreshToken(
            member = member,
            validUntil = LocalDateTime.now().plusDays(1),
            remoteAddr = "127.0.0.1",
            userAgent = null
        )
        refreshToken.userAgent = userAgent

        val tokenIdField = RefreshToken::class.java.getDeclaredField("id")
        tokenIdField.isAccessible = true
        tokenIdField.set(refreshToken, 1L)

        return refreshToken
    }
}
