package com.tistory.shanepark.dutypark.security.domain.entity

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.assertj.core.api.Assertions
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class RefreshTokenTest {

    private val dept = Department("testDept")
    private val member = Member(name = "", email = "", password = "")

    init {
        member.department = dept
    }

    @Test
    fun `slideValidUntil update its remote Addr`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", "agent")
        refreshToken.slideValidUntil("127.0.0.1", "agent")

        Assertions.assertThat(refreshToken.remoteAddr).isEqualTo("127.0.0.1")
    }

    @Test
    fun `slideValidUntil extends validUntil`() {
        val validUntil = LocalDateTime.now().plusDays(1)
        val refreshToken = RefreshToken(member, validUntil, "", "agent")
        refreshToken.slideValidUntil("", "agent")

        Assertions.assertThat(refreshToken.validUntil).isAfter(validUntil)
    }

    @Test
    fun `slideValidUntil updates userAgent`() {
        val refreshToken = RefreshToken(member, LocalDateTime.now().plusDays(1), "", "agent")
        refreshToken.slideValidUntil("", "agent2")

        Assertions.assertThat(refreshToken.userAgent).isEqualTo("agent2")
    }

}
