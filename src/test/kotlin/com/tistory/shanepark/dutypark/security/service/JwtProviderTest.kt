package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.boot.env.YamlPropertySourceLoader
import org.springframework.core.io.FileSystemResource
import java.time.Instant
import java.util.Date

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

    @Test
    fun `rejects an unclassified JWT validation failure`() {
        val notActiveYet = Jwts.builder()
            .subject("7")
            .claim("name", "user7")
            .notBefore(Date.from(Instant.now().plusSeconds(60)))
            .expiration(Date.from(Instant.now().plusSeconds(600)))
            .signWith(TEST_KEY)
            .compact()

        assertThat(provider.validateToken(notActiveYet)).isEqualTo(TokenStatus.INVALID)
    }

    @Test
    fun `rejects a signed token whose required claims cannot be parsed`() {
        val malformedClaims = Jwts.builder()
            .subject("not-a-member-id")
            .claim("name", 1234)
            .expiration(Date.from(Instant.now().plusSeconds(600)))
            .signWith(TEST_KEY)
            .compact()

        assertThat(provider.validateToken(malformedClaims)).isEqualTo(TokenStatus.INVALID)
        assertThatThrownBy { provider.parseToken(malformedClaims) }
            .isInstanceOf(AuthException::class.java)
    }

    @Test
    fun `constructor rejects blank malformed and short secrets`() {
        listOf(
            "",
            "not-base64!",
            "c2hvcnQ=",
        ).forEach { secret ->
            assertThatThrownBy {
                JwtProvider(
                    dutyparkProperties = DutyparkProperties(),
                    jwtConfig = JwtConfig(secret, 600, 7),
                )
            }
                .isInstanceOf(IllegalArgumentException::class.java)
                .hasMessageContaining("JWT secret")
        }
    }

    @Test
    fun `default configuration requires JWT secret without a fallback`() {
        val jwtSecret = YamlPropertySourceLoader()
            .load("application", FileSystemResource("src/main/resources/application.yml"))
            .firstNotNullOfOrNull { it.getProperty("jwt.secret") }

        assertThat(jwtSecret).isEqualTo("\${JWT_SECRET}")
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }

    companion object {
        private const val TEST_SECRET = "WvQiOAms2XFyW/UnmfO/9xL24ch4IlfUikP9QohMuso="
        private val TEST_KEY = Keys.hmacShaKeyFor(Decoders.BASE64.decode(TEST_SECRET))
    }

}
