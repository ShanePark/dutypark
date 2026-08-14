package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.CookieConfig
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import com.tistory.shanepark.dutypark.security.service.LoginAttemptService
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.mock
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse

class AuthControllerUnitTest {

    @Test
    fun `logout clears cookies even when server token deletion fails`() {
        val refreshTokenService = mock<RefreshTokenService> {
            on { deleteByToken("refresh-token") } doThrow IllegalStateException("database unavailable")
        }
        val cookieService = CookieService(
            cookieConfig = CookieConfig(
                secure = true,
                sameSite = "Lax",
                domain = "example.com",
            ),
            jwtConfig = JwtConfig("secret", 600, 7),
        )
        val controller = AuthController(
            authService = mock<AuthService>(),
            cookieService = cookieService,
            refreshTokenService = refreshTokenService,
            jwtConfig = JwtConfig("secret", 600, 7),
            loginAttemptService = mock<LoginAttemptService>(),
        )
        val request = MockHttpServletRequest().apply {
            setCookies(Cookie("refresh_token", "refresh-token"))
        }
        val response = MockHttpServletResponse()

        assertThrows<IllegalStateException> {
            controller.logout(request, response)
        }

        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).hasSize(2)
        assertThat(response.getHeaders(HttpHeaders.SET_COOKIE)).allSatisfy {
            assertThat(it).contains("Max-Age=0")
        }
    }
}
