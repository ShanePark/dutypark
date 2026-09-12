package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.CookieConfig
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import com.tistory.shanepark.dutypark.security.service.JwtProvider
import io.jsonwebtoken.Clock
import io.jsonwebtoken.JwtParser
import io.jsonwebtoken.JwtParserBuilder
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import jakarta.servlet.FilterChain
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.SoftAssertions.assertSoftly
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.mockito.Mockito.CALLS_REAL_METHODS
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.mockingDetails
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.spy
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import java.security.MessageDigest
import java.time.Instant
import java.util.Date
import java.util.Optional
import javax.crypto.SecretKey

class JwtAuthenticationTest {

    @ParameterizedTest
    @ValueSource(booleans = [false, true])
    fun `each request verifies its token once and reloads authorization state`(useCookie: Boolean) {
        val token = token()
        withInstrumentedParser { fixture, parser, builder ->
            val startupBuilds = invocationCount(builder, "build")
            var previousMember: LoginMember? = null
            repeat(20) {
                val (request, response) = fixture.authenticate(token, useCookie)
                val member = request.getAttribute(LoginMember.ATTR_NAME) as LoginMember
                assertThat(member.id).isEqualTo(7L)
                assertThat(member.sessionId).isEqualTo(42L)
                assertThat(member.isAdmin).isFalse()
                assertThat(member).isNotSameAs(previousMember)
                assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isNull()
                assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
                member.isAdmin = true
                previousMember = member
            }

            val parses = invocationCount(parser, "parseSignedClaims")
            val requestBuilds = invocationCount(builder, "build") - startupBuilds
            val sessionChecks = invocationCount(fixture.refreshTokenService, "isSessionActive")
            val memberLoads = invocationCount(fixture.memberRepository, "findById")
            val inputHash = MessageDigest.getInstance("SHA-256").digest(token.toByteArray())
                .joinToString("") { "%02x".format(it) }
            println(
                "JWT_AUTH_WORK credential=${if (useCookie) "cookie" else "bearer"} requests=20 " +
                    "inputSha256=$inputHash signatureParses=$parses parserBuildsAtStartup=$startupBuilds " +
                    "parserBuildsForRequests=$requestBuilds sessionChecks=$sessionChecks memberLoads=$memberLoads"
            )
            assertSoftly {
                it.assertThat(parses).`as`("signature verifications for 20 requests").isEqualTo(20)
                it.assertThat(requestBuilds).`as`("parser builds after provider initialization").isZero()
                it.assertThat(sessionChecks).isEqualTo(20)
                it.assertThat(memberLoads).isEqualTo(20)
            }
        }
    }

    @ParameterizedTest
    @ValueSource(strings = ["malformed", "expired", "unsupported", "wrong-signature", "invalid-claims"])
    fun `invalid bearer falls back to valid cookie`(failure: String) {
        val fixture = Fixture()
        val (request, response) = fixture.authenticate(invalidToken(failure), cookieToken = token())

        assertThat((request.getAttribute(LoginMember.ATTR_NAME) as LoginMember).id).isEqualTo(7L)
        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isNull()
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
    }

    @Test
    fun `valid bearer takes priority over a valid cookie`() {
        val fixture = Fixture()
        whenever(fixture.refreshTokenService.isSessionActive(99L, 7L)).thenReturn(true)

        val (request, _) = fixture.authenticate(token(), cookieToken = token(sessionId = 99L))

        assertThat((request.getAttribute(LoginMember.ATTR_NAME) as LoginMember).sessionId).isEqualTo(42L)
        verify(fixture.refreshTokenService).isSessionActive(42L, 7L)
        verify(fixture.refreshTokenService, never()).isSessionActive(99L, 7L)
    }

    @Test
    fun `revoked bearer does not fall back to valid cookie or clear cookies`() {
        val fixture = Fixture()
        whenever(fixture.refreshTokenService.isSessionActive(99L, 7L)).thenReturn(false)

        val (request, response) = fixture.authenticate(token(sessionId = 99L), cookieToken = token())

        assertAuthenticationFailed(request)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
        verify(fixture.refreshTokenService, never()).isSessionActive(42L, 7L)
        verify(fixture.memberRepository, never()).findById(any())
    }

    @Test
    fun `suspended bearer does not fall back to valid cookie`() {
        val fixture = Fixture()
        fixture.member.suspend()

        val (request, response) = fixture.authenticate(token(), cookieToken = token(sessionId = 99L))

        assertAuthenticationFailed(request)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
        verify(fixture.refreshTokenService, never()).isSessionActive(99L, 7L)
    }

    @Test
    fun `revoked cookie clears access and refresh cookies`() {
        val fixture = Fixture()
        whenever(fixture.refreshTokenService.isSessionActive(42L, 7L)).thenReturn(false)

        val (request, response) = fixture.authenticate(token(), useCookie = true)

        assertAuthenticationFailed(request)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).hasSize(2)
            .allSatisfy { assertThat(it).contains("Max-Age=0") }
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE))
            .anySatisfy { assertThat(it).startsWith("access_token=") }
            .anySatisfy { assertThat(it).startsWith("refresh_token=") }
    }

    @ParameterizedTest
    @ValueSource(strings = ["malformed", "expired", "unsupported", "wrong-signature", "invalid-claims"])
    fun `invalid cookie leaves token cookies intact`(failure: String) {
        val fixture = Fixture()

        val (request, response) = fixture.authenticate(invalidToken(failure), useCookie = true)

        assertAuthenticationFailed(request)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
        verify(fixture.refreshTokenService, never()).isSessionActive(any(), any())
        verify(fixture.memberRepository, never()).findById(any())
    }

    @Test
    fun `legacy token without session binding still checks current member`() {
        val fixture = Fixture()

        val (request, _) = fixture.authenticate(token(sessionId = null))

        assertThat((request.getAttribute(LoginMember.ATTR_NAME) as LoginMember).sessionId).isNull()
        verify(fixture.refreshTokenService, never()).isSessionActive(any(), any())
        verify(fixture.memberRepository).findById(7L)
    }

    @Test
    fun `impersonation checks original member session ownership`() {
        val fixture = Fixture()
        whenever(fixture.refreshTokenService.isSessionActive(42L, 8L)).thenReturn(true)

        val (request, _) = fixture.authenticate(token(originalMemberId = "8", impersonated = true))

        val loginMember = request.getAttribute(LoginMember.ATTR_NAME) as LoginMember
        assertThat(loginMember.isImpersonating).isTrue()
        assertThat(loginMember.originalMemberId).isEqualTo(8L)
        verify(fixture.refreshTokenService).isSessionActive(42L, 8L)
        verify(fixture.refreshTokenService, never()).isSessionActive(42L, 7L)
        verify(fixture.memberRepository).findById(7L)
    }

    @Test
    fun `impersonation without original session owner is rejected`() {
        val fixture = Fixture()

        val (request, _) = fixture.authenticate(token(impersonated = true))

        assertAuthenticationFailed(request)
        verify(fixture.refreshTokenService, never()).isSessionActive(any(), any())
        verify(fixture.memberRepository, never()).findById(any())
    }

    @Test
    fun `same token is rejected on the next request after its session is revoked`() {
        val fixture = Fixture()
        val token = token()
        assertThat(fixture.authenticate(token).first.getAttribute(LoginMember.ATTR_NAME)).isNotNull()
        whenever(fixture.refreshTokenService.isSessionActive(42L, 7L)).thenReturn(false)

        assertAuthenticationFailed(fixture.authenticate(token).first)

        verify(fixture.refreshTokenService, times(2)).isSessionActive(42L, 7L)
        verify(fixture.memberRepository).findById(7L)
    }

    @Test
    fun `same token is rejected on the next request after its member is suspended`() {
        val fixture = Fixture()
        val token = token()
        assertThat(fixture.authenticate(token).first.getAttribute(LoginMember.ATTR_NAME)).isNotNull()
        fixture.member.suspend()

        assertAuthenticationFailed(fixture.authenticate(token).first)

        verify(fixture.refreshTokenService, times(2)).isSessionActive(42L, 7L)
        verify(fixture.memberRepository, times(2)).findById(7L)
    }

    @Test
    fun `reused parser checks expiration against the current request time`() {
        val expiration = Instant.parse("2030-01-01T00:00:00Z")
        var now = Date.from(expiration.minusMillis(1))
        val token = token(expiration = expiration)
        withInstrumentedParser(Clock { now }) { fixture, _, _ ->
            assertThat(fixture.authenticate(token, useCookie = true).first.getAttribute(LoginMember.ATTR_NAME))
                .isNotNull()
            now = Date.from(expiration.plusMillis(1))

            val (request, response) = fixture.authenticate(token, useCookie = true)

            assertAuthenticationFailed(request)
            assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
            verify(fixture.refreshTokenService).isSessionActive(42L, 7L)
            verify(fixture.memberRepository).findById(7L)
        }
    }

    private fun withInstrumentedParser(
        clock: Clock = Clock { Date() },
        block: (Fixture, JwtParser, JwtParserBuilder) -> Unit,
    ) {
        val parser = spy(Jwts.parser().verifyWith(TEST_KEY).clock(clock).build())
        val builder = mock<JwtParserBuilder>()
        whenever(builder.verifyWith(any<SecretKey>())).thenReturn(builder)
        whenever(builder.build()).thenReturn(parser)
        mockStatic(Jwts::class.java, CALLS_REAL_METHODS).use { jwts ->
            jwts.`when`<JwtParserBuilder> { Jwts.parser() }.thenReturn(builder)
            block(Fixture(), parser, builder)
        }
    }

    private fun invocationCount(mock: Any, methodName: String): Int =
        mockingDetails(mock).invocations.count { it.method.name == methodName }

    private fun assertAuthenticationFailed(request: MockHttpServletRequest) {
        assertThat(request.getAttribute(LoginMember.ATTR_NAME)).isNull()
        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isEqualTo(true)
    }

    private class Fixture {
        val memberRepository = mock<MemberRepository>()
        val refreshTokenService = mock<RefreshTokenService>()
        val member = Member("user7", "user7@duty.park", "pass").also {
            Member::class.java.getDeclaredField("id").apply { isAccessible = true }.set(it, 7L)
        }
        private val jwtConfig = JwtConfig(TEST_SECRET, 600, 7)
        private val authService = AuthService(
            memberRepository = memberRepository,
            memberManagerRepository = mock(),
            passwordEncoder = mock(),
            refreshTokenService = refreshTokenService,
            jwtProvider = JwtProvider(DutyparkProperties(), jwtConfig),
            jwtConfig = jwtConfig,
            loginAttemptService = mock(),
            entityManager = mock(),
        )
        private val filter = JwtAuthFilter(
            authService,
            CookieService(CookieConfig(secure = true, sameSite = "Lax", domain = "example.com"), jwtConfig),
        )

        init {
            whenever(memberRepository.findById(7L)).thenReturn(Optional.of(member))
            whenever(refreshTokenService.isSessionActive(42L, 7L)).thenReturn(true)
        }

        fun authenticate(
            token: String,
            useCookie: Boolean = false,
            cookieToken: String? = null,
        ): Pair<MockHttpServletRequest, MockHttpServletResponse> {
            val request = MockHttpServletRequest("GET", "/api/members/me").apply {
                if (useCookie) {
                    setCookies(Cookie(CookieService.ACCESS_TOKEN_COOKIE, token))
                } else {
                    addHeader(HttpHeaders.AUTHORIZATION, "Bearer $token")
                    cookieToken?.let { setCookies(Cookie(CookieService.ACCESS_TOKEN_COOKIE, it)) }
                }
            }
            val response = MockHttpServletResponse()
            var chainInvoked = false
            filter.doFilter(request, response, FilterChain { _, _ -> chainInvoked = true })
            assertThat(chainInvoked).isTrue()
            return request to response
        }
    }

    companion object {
        private const val TEST_SECRET = "WvQiOAms2XFyW/UnmfO/9xL24ch4IlfUikP9QohMuso="
        private val TEST_KEY = Keys.hmacShaKeyFor(Decoders.BASE64.decode(TEST_SECRET))

        private fun invalidToken(failure: String): String = when (failure) {
            "malformed" -> "invalid-token"
            "expired" -> token(expiration = Instant.parse("2000-01-01T00:00:00Z"))
            "unsupported" -> Jwts.builder().subject("7").claim("name", "user7").compact()
            "wrong-signature" -> Jwts.builder().subject("7").claim("name", "user7")
                .signWith(Keys.hmacShaKeyFor(ByteArray(32) { 1 })).compact()
            "invalid-claims" -> Jwts.builder().subject("not-a-member-id").claim("name", "user7")
                .signWith(TEST_KEY).compact()
            else -> error("Unknown token failure: $failure")
        }

        private fun token(
            sessionId: Long? = 42L,
            originalMemberId: String? = null,
            impersonated: Boolean = false,
            expiration: Instant = Instant.parse("2099-01-01T00:00:00Z"),
        ): String = Jwts.builder()
            .subject("7")
            .claim("name", "user7")
            .claim("email", "user7@duty.park")
            .claim("sessionId", sessionId)
            .claim("originalSub", originalMemberId)
            .claim("impersonated", impersonated)
            .expiration(Date.from(expiration))
            .signWith(TEST_KEY)
            .compact()
    }
}
