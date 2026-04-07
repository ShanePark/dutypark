package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenDtoTest {

    private val chromeUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private val longAndroidChromeUserAgent =
        "Mozilla/5.0 (" +
                "DutyParkApp/6.0; ".repeat(18) +
                "Linux; Android 14; Pixel 8 Pro) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/122.0.0.0 Mobile Safari/537.36"

    @Test
    fun `of parses raw user agent values`() {
        val refreshToken = refreshToken(userAgent = chromeUserAgent)

        val result = RefreshTokenDto.of(refreshToken)

        assertThat(result.userAgent?.browser).isEqualTo("Chrome")
        assertThat(result.userAgent?.os).isEqualTo("Windows NT")
    }

    @Test
    fun `of preserves browser and device for user agents longer than legacy 255 limit`() {
        val refreshToken = refreshToken(userAgent = longAndroidChromeUserAgent)

        val result = RefreshTokenDto.of(refreshToken)

        assertThat(longAndroidChromeUserAgent.length).isGreaterThan(255)
        assertThat(result.userAgent?.os).isEqualTo("Android")
        assertThat(result.userAgent?.browser).isEqualTo("Chrome")
        assertThat(result.userAgent?.device).isEqualTo("Android Mobile")
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
        val member = member()

        val refreshToken = RefreshToken(
            member = member,
            validUntil = LocalDateTime.now().plusDays(1),
            remoteAddr = "127.0.0.1",
            userAgent = userAgent
        )

        val tokenIdField = RefreshToken::class.java.getDeclaredField("id")
        tokenIdField.isAccessible = true
        tokenIdField.set(refreshToken, 1L)

        return refreshToken
    }

    private fun member(): Member {
        val member = Member(name = "tester", email = "tester@duty.park", password = "secret")
        val memberIdField = Member::class.java.getDeclaredField("id")
        memberIdField.isAccessible = true
        memberIdField.set(member, 1L)
        return member
    }
}
