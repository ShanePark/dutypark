package com.tistory.shanepark.dutypark.security.filters

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.security.config.CookieConfig
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.FilterChain
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse

class JwtAuthFilterTest {

    private val authService = mock<AuthService>()
    private val cookieService = CookieService(
        cookieConfig = CookieConfig(secure = true, sameSite = "Lax", domain = "example.com"),
        jwtConfig = JwtConfig("secret", 600, 7),
    )
    private val filter = JwtAuthFilter(authService, cookieService)

    @Test
    fun `legacy access cookie remains usable without clearing refresh cookie`() {
        val request = MockHttpServletRequest("GET", "/api/members/me").apply {
            setCookies(
                Cookie(CookieService.ACCESS_TOKEN_COOKIE, "legacy-access"),
                Cookie(CookieService.REFRESH_TOKEN_COOKIE, "existing-refresh"),
            )
        }
        val response = MockHttpServletResponse()
        val loginMember = LoginMember(id = 1L, name = "legacy")
        whenever(authService.authenticateToken("legacy-access")).thenReturn(loginMember)
        var chainInvoked = false

        filter.doFilter(request, response, FilterChain { _, _ -> chainInvoked = true })

        assertThat(chainInvoked).isTrue()
        assertThat(request.getAttribute(LoginMember.ATTR_NAME)).isEqualTo(loginMember)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
    }

    @Test
    fun `legacy bearer token does not clear refresh cookie`() {
        val request = MockHttpServletRequest("GET", "/api/members/me").apply {
            addHeader(HttpHeaders.AUTHORIZATION, "Bearer legacy-access")
            setCookies(Cookie(CookieService.REFRESH_TOKEN_COOKIE, "existing-refresh"))
        }
        val response = MockHttpServletResponse()
        val loginMember = LoginMember(id = 1L, name = "legacy")
        whenever(authService.authenticateToken("legacy-access")).thenReturn(loginMember)

        filter.doFilter(request, response, FilterChain { _, _ -> })

        assertThat(request.getAttribute(LoginMember.ATTR_NAME)).isEqualTo(loginMember)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).isEmpty()
    }

    @Test
    fun `request without authentication credentials is not marked as failed authentication`() {
        val request = MockHttpServletRequest("POST", "/api/inquiries")

        filter.doFilter(request, MockHttpServletResponse(), FilterChain { _, _ -> })

        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isNull()
    }

    @Test
    fun `invalid bearer token is marked as failed authentication`() {
        val request = MockHttpServletRequest("POST", "/api/inquiries").apply {
            addHeader(HttpHeaders.AUTHORIZATION, "Bearer invalid-access")
        }
        whenever(authService.authenticateToken("invalid-access")).thenReturn(null)

        filter.doFilter(request, MockHttpServletResponse(), FilterChain { _, _ -> })

        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isEqualTo(true)
    }

    @Test
    fun `invalid access cookie is marked as failed authentication`() {
        val request = MockHttpServletRequest("POST", "/api/inquiries").apply {
            setCookies(Cookie(CookieService.ACCESS_TOKEN_COOKIE, "invalid-access"))
        }
        whenever(authService.authenticateToken("invalid-access")).thenReturn(null)

        filter.doFilter(request, MockHttpServletResponse(), FilterChain { _, _ -> })

        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isEqualTo(true)
    }

    @Test
    fun `member or session validation failure is marked as failed authentication`() {
        val request = MockHttpServletRequest("POST", "/api/inquiries").apply {
            addHeader(HttpHeaders.AUTHORIZATION, "Bearer inactive-member-access")
        }
        whenever(authService.authenticateToken("inactive-member-access"))
            .thenThrow(AuthException("auth.account.inactive"))

        filter.doFilter(request, MockHttpServletResponse(), FilterChain { _, _ -> })

        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isEqualTo(true)
        assertThat(request.getAttribute(LoginMember.ATTR_NAME)).isNull()
    }

    @Test
    fun `valid cookie fallback clears failed bearer authentication`() {
        val request = MockHttpServletRequest("POST", "/api/inquiries").apply {
            addHeader(HttpHeaders.AUTHORIZATION, "Bearer invalid-access")
            setCookies(Cookie(CookieService.ACCESS_TOKEN_COOKIE, "valid-cookie-access"))
        }
        val loginMember = LoginMember(id = 1L, name = "cookie-user")
        whenever(authService.authenticateToken("invalid-access")).thenReturn(null)
        whenever(authService.authenticateToken("valid-cookie-access")).thenReturn(loginMember)

        filter.doFilter(request, MockHttpServletResponse(), FilterChain { _, _ -> })

        assertThat(request.getAttribute(JwtAuthFilter.AUTHENTICATION_FAILED_ATTRIBUTE)).isNull()
        assertThat(request.getAttribute(LoginMember.ATTR_NAME)).isEqualTo(loginMember)
    }
}
