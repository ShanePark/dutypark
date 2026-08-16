package com.tistory.shanepark.dutypark.security.domain.entity

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.enums.ClientType
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenTest {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    private val team = Team("testTeam")
    private val member = Member(name = "", email = "", password = "")

    private val chromeUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private val firefoxUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    private val longUserAgent = "dp-test-" + "x".repeat(320)
    private val nativeAppUserAgent = "Dutypark/1 CFNetwork/3826.500.111.2.2 Darwin/24.4.0"

    /**
     * Captured on the wire from the Dutypark.app process on an iOS 26.5 simulator, which sets no
     * custom User-Agent and so sends the one CFNetwork derives from the app bundle.
     * Keeps the detection predicate anchored to a real user agent rather than an assumed shape.
     */
    private val capturedNativeAppUserAgent = "Dutypark/1 CFNetwork/3860.600.12 Darwin/25.5.0"

    init {
        member.team = team
    }

    @Test
    fun `slideValidUntil update its remote Addr`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", chromeUserAgent)
        refreshToken.slideValidUntil("127.0.0.1", chromeUserAgent, 7)

        Assertions.assertThat(refreshToken.remoteAddr).isEqualTo("127.0.0.1")
    }

    @Test
    fun `slideValidUntil extends validUntil`() {
        val validUntil = fixedDateTime.plusDays(1)
        val refreshToken = RefreshToken(member, validUntil, "", chromeUserAgent)
        refreshToken.slideValidUntil("", chromeUserAgent, 7)

        Assertions.assertThat(refreshToken.validUntil).isAfter(validUntil)
    }

    @Test
    fun `slideValidUntil updates userAgent`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", chromeUserAgent)
        val originalUserAgent = refreshToken.userAgent

        refreshToken.slideValidUntil("", firefoxUserAgent, 7)

        Assertions.assertThat(refreshToken.userAgent).isNotEqualTo(originalUserAgent)
        Assertions.assertThat(refreshToken.userAgent).isEqualTo(firefoxUserAgent)
    }

    @Test
    fun `refresh token stores raw userAgent without eager parsing`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", chromeUserAgent)

        Assertions.assertThat(refreshToken.userAgent).isEqualTo(chromeUserAgent)
    }

    @Test
    fun `refresh token keeps userAgent longer than legacy 255 limit`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", longUserAgent)

        Assertions.assertThat(refreshToken.userAgent).isEqualTo(longUserAgent)
    }

    @Test
    fun `native app user agent creates an IOS_APP session`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", nativeAppUserAgent)

        Assertions.assertThat(refreshToken.clientType).isEqualTo(ClientType.IOS_APP)
    }

    @Test
    fun `user agent captured from the real iOS app creates an IOS_APP session`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", capturedNativeAppUserAgent)

        Assertions.assertThat(refreshToken.clientType).isEqualTo(ClientType.IOS_APP)
    }

    @Test
    fun `browser user agent creates a BROWSER session`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", chromeUserAgent)

        Assertions.assertThat(refreshToken.clientType).isEqualTo(ClientType.BROWSER)
    }

    @Test
    fun `missing user agent creates a BROWSER session`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", null)

        Assertions.assertThat(refreshToken.clientType).isEqualTo(ClientType.BROWSER)
    }

    @Test
    fun `slideValidUntil never downgrades an IOS_APP session to BROWSER`() {
        val refreshToken = RefreshToken(member, fixedDateTime.plusDays(1), "", nativeAppUserAgent)

        refreshToken.slideValidUntil("127.0.0.1", null, 7)
        Assertions.assertThat(refreshToken.clientType).isEqualTo(ClientType.IOS_APP)

        refreshToken.slideValidUntil("127.0.0.1", chromeUserAgent, 7)
        Assertions.assertThat(refreshToken.clientType).isEqualTo(ClientType.IOS_APP)
    }

}
