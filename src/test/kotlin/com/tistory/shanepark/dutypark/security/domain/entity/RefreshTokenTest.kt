package com.tistory.shanepark.dutypark.security.domain.entity

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenTest {

    private val team = Team("testTeam")
    private val member = Member(name = "", email = "", password = "")

    private val chromeUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private val firefoxUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"

    init {
        member.team = team
    }

    @Test
    fun `slideValidUntil update its remote Addr`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", chromeUserAgent)
        refreshToken.slideValidUntil("127.0.0.1", chromeUserAgent, 7)

        Assertions.assertThat(refreshToken.remoteAddr).isEqualTo("127.0.0.1")
    }

    @Test
    fun `slideValidUntil extends validUntil`() {
        val validUntil = LocalDateTime.now().plusDays(1)
        val refreshToken = RefreshToken(member, validUntil, "", chromeUserAgent)
        refreshToken.slideValidUntil("", chromeUserAgent, 7)

        Assertions.assertThat(refreshToken.validUntil).isAfter(validUntil)
    }

    @Test
    fun `slideValidUntil updates userAgent`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", chromeUserAgent)
        val originalUserAgent = refreshToken.userAgent

        refreshToken.slideValidUntil("", firefoxUserAgent, 7)

        Assertions.assertThat(refreshToken.userAgent).isNotEqualTo(originalUserAgent)
        Assertions.assertThat(refreshToken.userAgent).contains("Firefox")
    }

}
