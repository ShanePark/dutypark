package com.tistory.shanepark.dutypark.security.domain.entity

import com.tistory.shanepark.dutypark.member.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenTest {

    private val dept = Department("testDept")
    private val member = Member(department = dept, name = "", email = "", password = "")

    @Test
    fun `validation update its remote Addr`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", "agent")
        refreshToken.validation("127.0.0.1", "agent")

        Assertions.assertThat(refreshToken.remoteAddr).isEqualTo("127.0.0.1")
    }

    @Test
    fun `validation extends validUntil`() {
        val validUntil = LocalDateTime.now().plusDays(1)
        val refreshToken = RefreshToken(member, validUntil, "", "agent")
        refreshToken.validation("", "agent")

        Assertions.assertThat(refreshToken.validUntil).isAfter(validUntil)
    }

    @Test
    fun `validation updates userAgent`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", "agent")
        refreshToken.validation("", "agent2")

        Assertions.assertThat(refreshToken.userAgent).isEqualTo("agent2")
    }

}
