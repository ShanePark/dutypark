package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.security.config.CookieConfig
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockHttpServletResponse

class CookieServiceTest {

    private val cookieService = CookieService(
        cookieConfig = CookieConfig(secure = false, sameSite = "Lax", domain = "example.com"),
        jwtConfig = JwtConfig(secret = "secret", tokenValidityInSeconds = 600, refreshTokenValidityInDays = 7)
    )

    @Test
    fun `setTokenCookies adds access and refresh cookies`() {
        val response = MockHttpServletResponse()

        cookieService.setTokenCookies(response, "access-token", "refresh-token")

        val cookies = response.getHeaders(HttpHeaders.SET_COOKIE)
        assertThat(cookies).hasSize(2)
        assertThat(cookies.any { it.contains("access_token=access-token") }).isTrue
        assertThat(cookies.any { it.contains("refresh_token=refresh-token") }).isTrue
    }

    @Test
    fun `setAccessTokenCookie sets path and domain`() {
        val response = MockHttpServletResponse()

        cookieService.setAccessTokenCookie(response, "access-token")

        val cookieHeader = response.getHeader(HttpHeaders.SET_COOKIE) ?: ""
        assertThat(cookieHeader).contains("access_token=access-token")
        assertThat(cookieHeader).contains("Path=/")
        assertThat(cookieHeader).contains("Domain=example.com")
    }

    @Test
    fun `setRefreshTokenCookie sets auth path`() {
        val response = MockHttpServletResponse()

        cookieService.setRefreshTokenCookie(response, "refresh-token")

        val cookieHeader = response.getHeader(HttpHeaders.SET_COOKIE) ?: ""
        assertThat(cookieHeader).contains("refresh_token=refresh-token")
        assertThat(cookieHeader).contains("Path=/api/auth")
    }

    @Test
    fun `clearTokenCookies sets max age zero`() {
        val response = MockHttpServletResponse()

        cookieService.clearTokenCookies(response)

        val cookies = response.getHeaders(HttpHeaders.SET_COOKIE)
        assertThat(cookies).hasSize(2)
        assertThat(cookies.all { it.contains("Max-Age=0") }).isTrue
    }

    @Test
    fun `extract tokens from cookies`() {
        val cookies = arrayOf(
            Cookie(CookieService.ACCESS_TOKEN_COOKIE, "access"),
            Cookie(CookieService.REFRESH_TOKEN_COOKIE, "refresh")
        )

        assertThat(cookieService.extractAccessToken(cookies)).isEqualTo("access")
        assertThat(cookieService.extractRefreshToken(cookies)).isEqualTo("refresh")
    }

    @Test
    fun `extract tokens returns null when absent`() {
        val cookies = arrayOf(Cookie("other", "value"))

        assertThat(cookieService.extractAccessToken(cookies)).isNull()
        assertThat(cookieService.extractRefreshToken(cookies)).isNull()
        assertThat(cookieService.extractAccessToken(null)).isNull()
    }
}
