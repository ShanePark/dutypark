package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class JwtProviderTest {

    private val provider = JwtProvider(
        dutyparkProperties = DutyparkProperties(),
        jwtConfig = JwtConfig(
            secret = "WvQiOAms2XFyW/UnmfO/9xL24ch4IlfUikP9QohMuso=",
            tokenValidityInSeconds = 600,
            refreshTokenValidityInDays = 7,
        ),
    )

    @Test
    fun `access token carries refresh session binding`() {
        val member = memberWithId(7L)

        val parsed = provider.parseToken(provider.createToken(member, sessionId = 42L))

        assertThat(parsed.id).isEqualTo(7L)
        assertThat(parsed.sessionId).isEqualTo(42L)
    }

    @Test
    fun `impersonation token keeps original refresh session binding`() {
        val target = memberWithId(8L)

        val parsed = provider.parseToken(
            provider.createImpersonationToken(target, originalMemberId = 7L, sessionId = 42L)
        )

        assertThat(parsed.id).isEqualTo(8L)
        assertThat(parsed.originalMemberId).isEqualTo(7L)
        assertThat(parsed.sessionId).isEqualTo(42L)
        assertThat(parsed.isImpersonating).isTrue()
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }
}
