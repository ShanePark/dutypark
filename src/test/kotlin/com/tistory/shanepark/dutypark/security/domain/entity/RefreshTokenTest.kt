package com.tistory.shanepark.dutypark.security.domain.entity

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenTest {

    private val team = Team("testTeam")
    private val member = Member(name = "", email = "", password = "")

    init {
        member.team = team
    }

    @Test
    fun `slideValidUntil update its remote Addr`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", "agent")
        refreshToken.slideValidUntil("127.0.0.1", "agent", 7)

        Assertions.assertThat(refreshToken.remoteAddr).isEqualTo("127.0.0.1")
    }

    @Test
    fun `slideValidUntil extends validUntil`() {
        val validUntil = LocalDateTime.now().plusDays(1)
        val refreshToken = RefreshToken(member, validUntil, "", "agent")
        refreshToken.slideValidUntil("", "agent", 7)

        Assertions.assertThat(refreshToken.validUntil).isAfter(validUntil)
    }

    @Test
    fun `slideValidUntil updates userAgent`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", "agent")
        refreshToken.slideValidUntil("", "agent2", 7)

        Assertions.assertThat(refreshToken.userAgent).isEqualTo("agent2")
    }

}
